import { Injectable, NotFoundException } from '@nestjs/common';
import { HealthReminderStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class HealthRemindersService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string) {
    return this.prisma.healthReminder.findMany({
      where: { userId },
      orderBy: { scheduledAt: 'desc' },
    });
  }

  async getDetail(userId: string, id: string) {
    const reminder = await this.prisma.healthReminder.findUnique({ where: { id } });
    if (!reminder || reminder.userId !== userId) {
      throw new NotFoundException('Health reminder not found');
    }
    return reminder;
  }

  /** Due = scheduled at/before now and still pending; upcoming = still pending, in the future. */
  async getUpcoming(userId: string) {
    return this.prisma.healthReminder.findMany({
      where: { userId, status: HealthReminderStatus.PENDING, scheduledAt: { gt: new Date() } },
      orderBy: { scheduledAt: 'asc' },
    });
  }

  async getDue(userId: string) {
    return this.prisma.healthReminder.findMany({
      where: { userId, status: HealthReminderStatus.PENDING, scheduledAt: { lte: new Date() } },
      orderBy: { scheduledAt: 'asc' },
    });
  }

  /**
   * Idempotent for the same reason dose-completion is: a retried sync
   * operation on an already-COMPLETED reminder is a no-op success rather
   * than an error, so the offline queue can safely retry without
   * duplicating side effects (there are none here beyond the status
   * itself, but the pattern matches `markDoseTaken` intentionally).
   */
  async markComplete(userId: string, id: string, completedAt?: string) {
    const reminder = await this.getDetail(userId, id);
    if (reminder.status === HealthReminderStatus.COMPLETED) {
      return reminder;
    }
    return this.prisma.healthReminder.update({
      where: { id },
      data: {
        status: HealthReminderStatus.COMPLETED,
        completedAt: completedAt ? new Date(completedAt) : new Date(),
      },
    });
  }
}
