import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { AccountStatus, DoseStatus, NotificationType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService, NewNotification } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import { missedCutoff } from './lib/dose-status.util';

const BATCH_SIZE = 200;

/** Doses that went missed longer ago than this are closed WITHOUT alerting (stale / backlog after downtime). */
function alertMaxAgeMs(): number {
  const raw = Number(process.env.MISSED_ALERT_MAX_AGE_MINUTES);
  return (Number.isFinite(raw) && raw > 0 ? raw : 360) * 60_000;
}

/**
 * Missed-dose pipeline:
 *
 *   PENDING dose past grace ─(sweep)→ MISSED ─(claim once)→ family notifications ─→ push
 *
 * Why a background job rather than only the "sweep on read" the schedule
 * service already does: the person who missed a dose is, by definition, often
 * NOT using the app. Detection must not depend on them opening it.
 *
 * Exactly-once alerting, in three layers:
 *   1. CLAIM  — `familyAlertProcessedAt` is set with a compare-and-set
 *               (`WHERE ... IS NULL`) inside the same transaction that creates
 *               the notifications. Overlapping runs/instances: one wins.
 *   2. UNIQUE — notifications are unique on (recipient, type, dose id), so even
 *               a bug in (1) cannot create a second row.
 *   3. PUSH   — the dispatcher claims each notification before sending and
 *               never re-sends a SENT one.
 */
@Injectable()
export class MissedDoseAlertService {
  private readonly logger = new Logger(MissedDoseAlertService.name);
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async handleCron() {
    if (this.running || process.env.MISSED_DOSE_JOB_ENABLED === 'false') return;
    this.running = true;
    try {
      await this.run();
    } catch (err) {
      this.logger.error(`Missed-dose job failed: ${(err as Error).message}`);
    } finally {
      this.running = false;
    }
  }

  /** One pass. Public so it can be unit-tested and triggered manually. */
  async run(now: Date = new Date()): Promise<{ swept: number; alerted: number }> {
    // 1. Detect: any PENDING dose past the grace window is MISSED (idempotent).
    const sweep = await this.prisma.medicineDose.updateMany({
      where: { status: DoseStatus.PENDING, scheduledAt: { lt: missedCutoff(now) } },
      data: { status: DoseStatus.MISSED },
    });

    // 2. Close out stale backlog silently so it is never reconsidered.
    const staleBefore = new Date(now.getTime() - alertMaxAgeMs());
    await this.prisma.medicineDose.updateMany({
      where: {
        status: DoseStatus.MISSED,
        familyAlertProcessedAt: null,
        scheduledAt: { lt: staleBefore },
      },
      data: { familyAlertProcessedAt: now },
    });

    // 3. Alert for recent unhandled missed doses.
    const candidates = await this.prisma.medicineDose.findMany({
      where: {
        status: DoseStatus.MISSED,
        familyAlertProcessedAt: null,
        scheduledAt: { gte: staleBefore },
      },
      orderBy: { scheduledAt: 'asc' },
      take: BATCH_SIZE,
      select: {
        id: true,
        userId: true,
        user: { select: { name: true, accountStatus: true, profileVisibleToFamily: true } },
      },
    });

    let alerted = 0;
    for (const dose of candidates) {
      try {
        alerted += await this.alertFamily(dose, now);
      } catch (err) {
        // Claim + notifications are one transaction, so a failure here leaves the dose
        // unclaimed and the next run retries it.
        this.logger.error(`Family alert failed for dose ${dose.id}: ${(err as Error).message}`);
      }
    }

    if (sweep.count > 0 || alerted > 0) {
      this.logger.log(`Missed-dose run: ${sweep.count} newly missed, ${alerted} family alerts created`);
    }
    return { swept: sweep.count, alerted };
  }

  private async alertFamily(
    dose: {
      id: string;
      userId: string;
      user: { name: string; accountStatus: AccountStatus; profileVisibleToFamily: boolean };
    },
    now: Date,
  ): Promise<number> {
    // Resolve recipients: the OTHER members of the subject's own family only,
    // and only if the subject shares with family. Subject opted out => the
    // dose is still claimed (so it is not re-evaluated) but nobody is told.
    let recipients: Array<{ id: string; languagePreference: 'EN' | 'BN' }> = [];
    if (dose.user.profileVisibleToFamily && dose.user.accountStatus === AccountStatus.ACTIVE) {
      const membership = await this.prisma.familyMember.findUnique({
        where: { userId: dose.userId },
        select: { familyId: true },
      });
      if (membership) {
        const others = await this.prisma.familyMember.findMany({
          where: {
            familyId: membership.familyId,
            userId: { not: dose.userId },
            user: { accountStatus: AccountStatus.ACTIVE },
          },
          select: { user: { select: { id: true, languagePreference: true } } },
        });
        recipients = others.map((o) => o.user);
      }
    }

    const createdIds = await this.prisma.$transaction(async (tx) => {
      const claim = await tx.medicineDose.updateMany({
        where: { id: dose.id, status: DoseStatus.MISSED, familyAlertProcessedAt: null },
        data: { familyAlertProcessedAt: now },
      });
      if (claim.count === 0) return []; // another run got it, or it was marked taken meanwhile

      const rows: NewNotification[] = recipients.map((r) => {
        const copy = messages.missedDoseFamily(r.languagePreference, dose.user.name);
        return {
          userId: r.id,
          type: NotificationType.MISSED_DOSE_FAMILY_ALERT,
          title: copy.title,
          body: copy.body,
          relatedEntityId: dose.id,
          // Routing only: who. Deliberately no medicine name / dose / time.
          data: { memberUserId: dose.userId },
        };
      });
      return this.notifications.createMany(rows, tx);
    });

    await this.notifications.dispatch(createdIds);
    return createdIds.length;
  }
}
