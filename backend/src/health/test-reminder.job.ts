import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { AccountStatus, FamilyRole, HealthReminderStatus, NotificationType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import { reminderTiming } from '../common/config/reminder-timing';

const DAY_MS = 24 * 60 * 60_000;
const BATCH_SIZE = 200;

/** The last day's ring (day TEST_REMINDER_DAYS): the caregiver is told. */
export function testCaregiverAlertAfterMs(): number {
  return (reminderTiming().testReminderDays - 1) * DAY_MS;
}
/** A day after the last ring, a test still not done is closed as MISSED. */
export function testMissedAfterMs(): number {
  return reminderTiming().testReminderDays * DAY_MS;
}

/**
 * Test reminders (health reminders with a testId; owner, 2026-10-31): the
 * app rings on day 1, 2 and 3 at the reminder's time until Done. On day 3
 * the family's caregiver gets a neutral alert (the member's name, never the
 * test), on the same rules as missed-dose alerts: the member shares with
 * family, has reminders on and is active; a caregiver is never alerted about
 * themself. A day later the reminder becomes MISSED.
 */
@Injectable()
export class TestReminderJob {
  private readonly logger = new Logger(TestReminderJob.name);
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  @Cron(CronExpression.EVERY_5_MINUTES)
  async handleCron() {
    if (this.running || process.env.TEST_REMINDER_JOB_ENABLED === 'false') return;
    this.running = true;
    try {
      await this.run();
    } catch (err) {
      this.logger.error(`Test-reminder job failed: ${(err as Error).message}`);
    } finally {
      this.running = false;
    }
  }

  async run(now: Date = new Date()): Promise<{ alerted: number; missed: number }> {
    const missed = await this.prisma.healthReminder.updateMany({
      where: {
        testId: { not: null },
        status: HealthReminderStatus.PENDING,
        scheduledAt: { lte: new Date(now.getTime() - testMissedAfterMs()) },
      },
      data: { status: HealthReminderStatus.MISSED },
    });

    let alerted = 0;
    for (;;) {
      const due = await this.prisma.healthReminder.findMany({
        where: {
          testId: { not: null },
          status: HealthReminderStatus.PENDING,
          caregiverAlertedAt: null,
          scheduledAt: { lte: new Date(now.getTime() - testCaregiverAlertAfterMs()) },
        },
        orderBy: [{ scheduledAt: 'asc' }, { id: 'asc' }],
        take: BATCH_SIZE,
        select: {
          id: true,
          userId: true,
          user: {
            select: {
              name: true,
              accountStatus: true,
              profileVisibleToFamily: true,
              medicineRemindersEnabled: true,
            },
          },
        },
      });
      for (const reminder of due) {
        try {
          alerted += await this.alertCaregiver(reminder, now);
        } catch (err) {
          this.logger.error(`Caregiver test alert failed for ${reminder.id}: ${(err as Error).message}`);
        }
      }
      // Every row of a batch is claimed (alerted or not), so the next query moves on.
      if (due.length < BATCH_SIZE) break;
    }
    return { alerted, missed: missed.count };
  }

  private async alertCaregiver(
    reminder: {
      id: string;
      userId: string;
      user: { name: string; accountStatus: AccountStatus; profileVisibleToFamily: boolean; medicineRemindersEnabled: boolean };
    },
    now: Date,
  ): Promise<number> {
    let caregiver: { id: string; languagePreference: 'EN' | 'BN' } | null = null;
    const { user } = reminder;
    if (user.profileVisibleToFamily && user.medicineRemindersEnabled && user.accountStatus === AccountStatus.ACTIVE) {
      const membership = await this.prisma.familyMember.findUnique({
        where: { userId: reminder.userId },
        select: { familyId: true },
      });
      if (membership) {
        const row = await this.prisma.familyMember.findFirst({
          where: {
            familyId: membership.familyId,
            role: FamilyRole.CAREGIVER,
            userId: { not: reminder.userId },
            user: { accountStatus: AccountStatus.ACTIVE },
          },
          select: { user: { select: { id: true, languagePreference: true } } },
        });
        caregiver = row?.user ?? null;
      }
    }

    const createdIds = await this.prisma.$transaction(async (tx) => {
      const claim = await tx.healthReminder.updateMany({
        where: { id: reminder.id, status: HealthReminderStatus.PENDING, caregiverAlertedAt: null },
        data: { caregiverAlertedAt: now },
      });
      if (claim.count === 0 || !caregiver) return [];
      const copy = messages.testPendingCaregiver(caregiver.languagePreference, user.name);
      return this.notifications.createMany(
        [
          {
            userId: caregiver.id,
            type: NotificationType.MISSED_DOSE_FAMILY_ALERT,
            title: copy.title,
            body: copy.body,
            relatedEntityId: `test:${reminder.id}`,
            // Routing only: who. No test name.
            data: { memberUserId: reminder.userId, kind: 'test_pending' },
          },
        ],
        tx,
      );
    });
    await this.notifications.dispatch(createdIds);
    return createdIds.length;
  }
}
