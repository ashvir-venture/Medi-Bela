import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { AccountStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { startOfAppDay } from '../common/utils/time.util';
import {
  dosesForDays,
  generationLimit,
  parseScheduleTimes,
} from '../prescriptions/lib/routine-generation.service';

const BATCH_SIZE = 200;
/** One hourly run stops taking new batches after this long (20,000 patients took ~80 s). */
const RUN_BUDGET_MS = 10 * 60_000;

/**
 * Keeps every active routine's doses generated ROLLING_HORIZON_DAYS ahead,
 * continuing from `generatedUntil` up to the routine's end (or with no end
 * for continuous lines). Routines without `scheduleTimes` (created before
 * Round 4) already have all their doses and are never touched.
 *
 * Exactly-once per day range: each extension is a compare-and-set on
 * `generatedUntil` in the same transaction as the dose inserts, so
 * overlapping runs can't create a day twice.
 *
 * Only ACTIVE accounts are extended. Pausing an account (deactivate / ban)
 * sets generatedUntil back to the start of that day; when it resumes the
 * extension starts from today and skips times already past, so nothing is
 * back-filled for the pause.
 */
@Injectable()
export class RollingDoseJob {
  private readonly logger = new Logger(RollingDoseJob.name);
  private running = false;

  constructor(private readonly prisma: PrismaService) {}

  @Cron(CronExpression.EVERY_HOUR)
  async handleCron() {
    if (this.running || process.env.ROLLING_DOSE_JOB_ENABLED === 'false') return;
    this.running = true;
    try {
      const created = await this.run();
      if (created > 0) this.logger.log(`Rolling dose run: ${created} doses created`);
    } catch (err) {
      this.logger.error(`Rolling dose job failed: ${(err as Error).message}`);
    } finally {
      this.running = false;
    }
  }

  /**
   * One pass over every routine that is behind; returns the number of doses
   * created. Public for tests and manual runs. Takes batches until the scan is
   * done (or RUN_BUDGET_MS is used up; the next hourly run continues), because
   * every routine needs one extension a day: one batch an hour fell behind
   * above ~4,800 routines.
   */
  async run(now: Date = new Date(), userId?: string): Promise<number> {
    const today = startOfAppDay(now);
    const horizonEnd = generationLimit(null, now);
    const started = Date.now();
    // Keyset cursor over (generatedUntil, id) as read: routines this pass
    // skips (a short course already generated to its end) or another run
    // extended are passed over instead of filling every batch again.
    let after: { generatedUntil: Date; id: string } | null = null;
    let created = 0;

    for (;;) {
      const routines: {
        id: string;
        userId: string;
        scheduleTimes: string | null;
        endDate: Date | null;
        generatedUntil: Date | null;
      }[] = await this.prisma.medicineRoutine.findMany({
        where: {
          active: true,
          scheduleTimes: { not: null },
          user: { accountStatus: AccountStatus.ACTIVE },
          ...(userId ? { userId } : {}),
          generatedUntil: { lt: horizonEnd },
          // Finished courses drop out, so the query stays small over time.
          OR: [{ endDate: null }, { endDate: { gte: today } }],
          ...(after
            ? {
                AND: [
                  {
                    OR: [
                      { generatedUntil: { gt: after.generatedUntil } },
                      { generatedUntil: after.generatedUntil, id: { gt: after.id } },
                    ],
                  },
                ],
              }
            : {}),
        },
        orderBy: [{ generatedUntil: 'asc' }, { id: 'asc' }],
        take: BATCH_SIZE,
        select: { id: true, userId: true, scheduleTimes: true, endDate: true, generatedUntil: true },
      });

      for (const routine of routines) {
        created += await extendRoutine(this.prisma, routine, now);
      }
      if (routines.length < BATCH_SIZE) break;
      const last = routines[routines.length - 1];
      after = { generatedUntil: last.generatedUntil!, id: last.id };
      if (Date.now() - started > RUN_BUDGET_MS) {
        this.logger.warn('Rolling-dose run stopped at its time budget; the next run continues');
        break;
      }
    }
    return created;
  }
}

/**
 * Generates one routine's doses from `generatedUntil` (or today, if that is
 * earlier: a paused account) up to its limit, skipping times already past.
 */
export async function extendRoutine(
  prisma: PrismaService,
  routine: { id: string; userId: string; scheduleTimes: string | null; endDate: Date | null; generatedUntil: Date | null },
  now: Date,
): Promise<number> {
  const stored = routine.generatedUntil!;
  const today = startOfAppDay(now);
  const from = stored < today ? today : stored;
  const until = generationLimit(routine.endDate, now);
  if (from >= until) return 0;
  const doses = dosesForDays(parseScheduleTimes(routine.scheduleTimes), from, until).filter(
    (d) => d.scheduledAt > now,
  );

  return prisma.$transaction(async (tx) => {
    const claim = await tx.medicineRoutine.updateMany({
      where: { id: routine.id, generatedUntil: stored },
      data: { generatedUntil: until },
    });
    if (claim.count === 0) return 0; // another run extended it first
    const result = await tx.medicineDose.createMany({
      data: doses.map((d) => ({ routineId: routine.id, userId: routine.userId, scheduledAt: d.scheduledAt })),
    });
    return result.count;
  });
}

/**
 * Pauses a user's schedules (inside the deactivate / ban / delete
 * transaction): future PENDING doses of routines the job can regenerate are
 * deleted, and generatedUntil goes back to the start of today so a later
 * resume continues from then. Routines from before Round 4 (no
 * scheduleTimes) can't be regenerated and are left as they are.
 */
export async function pauseSchedules(tx: Prisma.TransactionClient, userId: string, now: Date): Promise<void> {
  const routineFilter = { userId, active: true, scheduleTimes: { not: null } };
  await tx.medicineDose.deleteMany({
    where: { userId, status: 'PENDING', scheduledAt: { gt: now }, routine: routineFilter },
  });
  const today = startOfAppDay(now);
  await tx.medicineRoutine.updateMany({
    where: { ...routineFilter, generatedUntil: { gt: today } },
    data: { generatedUntil: today },
  });
}

/**
 * Extends one user's routines right away when their account becomes ACTIVE
 * again (reactivation or unban), so reminders return at sign-in instead of
 * at the next hourly run. A user has few routines: no batching.
 */
export async function resumeSchedules(prisma: PrismaService, userId: string, now: Date = new Date()): Promise<number> {
  const routines = await prisma.medicineRoutine.findMany({
    where: {
      userId,
      active: true,
      scheduleTimes: { not: null },
      generatedUntil: { not: null },
      OR: [{ endDate: null }, { endDate: { gte: startOfAppDay(now) } }],
    },
    select: { id: true, userId: true, scheduleTimes: true, endDate: true, generatedUntil: true },
  });
  let created = 0;
  for (const routine of routines) created += await extendRoutine(prisma, routine, now);
  return created;
}
