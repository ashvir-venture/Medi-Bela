import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { startOfAppDay } from '../common/utils/time.util';
import {
  dosesForDays,
  generationLimit,
  parseScheduleTimes,
} from '../prescriptions/lib/routine-generation.service';

const BATCH_SIZE = 200;

/**
 * Keeps every active routine's doses generated ROLLING_HORIZON_DAYS ahead,
 * continuing from `generatedUntil` up to the routine's end (or with no end
 * for continuous lines). Routines without `scheduleTimes` (created before
 * Round 4) already have all their doses and are never touched.
 *
 * Exactly-once per day range: each extension is a compare-and-set on
 * `generatedUntil` in the same transaction as the dose inserts, so
 * overlapping runs can't create a day twice.
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

  /** One pass; returns the number of doses created. Public for tests and manual runs. */
  async run(now: Date = new Date()): Promise<number> {
    const today = startOfAppDay(now);
    const horizonEnd = generationLimit(null, now);
    const routines = await this.prisma.medicineRoutine.findMany({
      where: {
        active: true,
        scheduleTimes: { not: null },
        generatedUntil: { lt: horizonEnd },
        // Finished courses drop out, so the query stays small over time.
        OR: [{ endDate: null }, { endDate: { gte: today } }],
      },
      orderBy: { generatedUntil: 'asc' },
      take: BATCH_SIZE,
      select: { id: true, userId: true, scheduleTimes: true, endDate: true, generatedUntil: true },
    });

    let created = 0;
    for (const routine of routines) {
      const from = routine.generatedUntil!;
      const until = generationLimit(routine.endDate, now);
      if (from >= until) continue;
      const doses = dosesForDays(parseScheduleTimes(routine.scheduleTimes), from, until);

      created += await this.prisma.$transaction(async (tx) => {
        const claim = await tx.medicineRoutine.updateMany({
          where: { id: routine.id, generatedUntil: from },
          data: { generatedUntil: until },
        });
        if (claim.count === 0) return 0; // another run extended it first
        const result = await tx.medicineDose.createMany({
          data: doses.map((d) => ({ routineId: routine.id, userId: routine.userId, scheduledAt: d.scheduledAt })),
        });
        return result.count;
      });
    }
    return created;
  }
}
