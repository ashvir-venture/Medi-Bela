import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { HealthReminderStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ErrorCode, withCode } from '../common/filters/error-codes';

/** Phone clocks run a little early or late: a tap this close before the time counts. */
const CLOCK_TOLERANCE_MS = 2 * 60_000;

/** Test reminders carry their meal timing and a `kind` the app can tell apart. */
const INCLUDE = { mealTiming: true } as const;

function present<T extends { testId: string | null }>(reminder: T) {
  return { ...reminder, kind: reminder.testId ? 'TEST' : 'RULE' };
}

@Injectable()
export class HealthRemindersService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string) {
    const rows = await this.prisma.healthReminder.findMany({
      where: { userId },
      orderBy: { scheduledAt: 'desc' },
      include: INCLUDE,
    });
    return rows.map(present);
  }

  async getDetail(userId: string, id: string) {
    const reminder = await this.prisma.healthReminder.findUnique({ where: { id }, include: INCLUDE });
    if (!reminder || reminder.userId !== userId) {
      throw new NotFoundException('Health reminder not found');
    }
    return present(reminder);
  }

  /** Due = scheduled at/before now and still pending; upcoming = still pending, in the future. */
  async getUpcoming(userId: string) {
    const rows = await this.prisma.healthReminder.findMany({
      where: { userId, status: HealthReminderStatus.PENDING, scheduledAt: { gt: new Date() } },
      orderBy: { scheduledAt: 'asc' },
      include: INCLUDE,
    });
    return rows.map(present);
  }

  async getDue(userId: string) {
    const rows = await this.prisma.healthReminder.findMany({
      where: { userId, status: HealthReminderStatus.PENDING, scheduledAt: { lte: new Date() } },
      orderBy: { scheduledAt: 'asc' },
      include: INCLUDE,
    });
    return rows.map(present);
  }

  /**
   * Idempotent for the same reason dose-completion is: a retried sync
   * operation on an already-COMPLETED reminder is a no-op success rather
   * than an error, so the offline queue can safely retry without
   * duplicating side effects (there are none here beyond the status
   * itself, but the pattern matches `markDoseTaken` intentionally).
   * A test reminder can't be done before its time (DOSE_NOT_DUE) or once
   * it was closed as MISSED (DOSE_WINDOW_CLOSED).
   */
  async markComplete(userId: string, id: string, completedAt?: string) {
    const reminder = await this.getDetail(userId, id);
    if (reminder.status === HealthReminderStatus.COMPLETED) {
      return reminder;
    }
    const at = completedAt ? new Date(completedAt) : new Date();
    if (reminder.testId) {
      if (at.getTime() < reminder.scheduledAt.getTime() - CLOCK_TOLERANCE_MS) {
        throw withCode(new ConflictException('This test is not due yet'), ErrorCode.DOSE_NOT_DUE);
      }
      if (reminder.status === HealthReminderStatus.MISSED) {
        throw withCode(new ConflictException('This test reminder has closed'), ErrorCode.DOSE_WINDOW_CLOSED);
      }
    }
    const updated = await this.prisma.healthReminder.update({
      where: { id },
      data: { status: HealthReminderStatus.COMPLETED, completedAt: at },
      include: INCLUDE,
    });
    return present(updated);
  }
}
