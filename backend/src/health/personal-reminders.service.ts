import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { NotificationType, PersonalReminder } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import { ActingFor, CaregiverAccessService } from '../family/caregiver-access.service';
import { startOfAppDay } from '../common/utils/time.util';
import { CreatePersonalReminderDto, UpdatePersonalReminderDto } from './dto/personal-reminder.dto';

function dateOnly(value: string): Date {
  return new Date(`${value}T00:00:00.000Z`);
}

/** Who set it up goes out only as a flag (ids stay server-side). */
export function presentPersonalReminder(r: PersonalReminder) {
  const { createdById, ...rest } = r;
  return { ...rest, byCaregiver: Boolean(createdById && createdById !== r.userId) };
}

/**
 * Personal health reminders (Round 13): the user's own "Time for your
 * {name}" reminders, or ones their caregiver set up for them. The phone
 * schedules them (banner, Done / Later); the server keeps the list and, when
 * the member presses Later on one the caregiver set up, tells the caregiver.
 */
@Injectable()
export class PersonalRemindersService {
  private readonly logger = new Logger(PersonalRemindersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  async list(userId: string) {
    const rows = await this.prisma.personalReminder.findMany({
      where: { userId, active: true },
      orderBy: { createdAt: 'asc' },
    });
    return rows.map(presentPersonalReminder);
  }

  async create(acting: ActingFor, dto: CreatePersonalReminderDto) {
    const today = startOfAppDay(new Date());
    const startDate = dto.startDate ? startOfAppDay(dateOnly(dto.startDate)) : today;
    if (startDate < today) throw new BadRequestException("The start date can't be in the past");
    const endDate = dto.endDate ? startOfAppDay(dateOnly(dto.endDate)) : null;
    if (endDate && endDate < startDate) throw new BadRequestException('The end date is before the start date');
    if (new Set(dto.scheduleTimes).size !== dto.scheduleTimes.length) {
      throw new BadRequestException('Each time can be chosen once');
    }

    const created = await this.prisma.$transaction(async (tx) => {
      const row = await tx.personalReminder.create({
        data: {
          userId: acting.subjectId,
          name: dto.name,
          description: dto.description || null,
          scheduleTimes: JSON.stringify(dto.scheduleTimes),
          intervalDays: dto.intervalDays ?? 1,
          startDate,
          endDate,
          createdById: acting.actorId,
        },
      });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'personal_reminder.create',
          entityType: 'personal_reminder',
          entityId: row.id,
          after: { times: dto.scheduleTimes.length, intervalDays: row.intervalDays, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
      return row;
    });
    await this.caregivers.notifyMember(acting, 'reminder_added', created.id);
    return presentPersonalReminder(created);
  }

  async update(acting: ActingFor, id: string, dto: UpdatePersonalReminderDto) {
    const current = await this.own(acting.subjectId, id);
    if (dto.scheduleTimes && new Set(dto.scheduleTimes).size !== dto.scheduleTimes.length) {
      throw new BadRequestException('Each time can be chosen once');
    }
    const endDate =
      dto.endDate === undefined ? current.endDate : dto.endDate === null ? null : startOfAppDay(dateOnly(dto.endDate));
    if (endDate && endDate < current.startDate) throw new BadRequestException('The end date is before the start date');
    const now = new Date();

    const saved = await this.prisma.$transaction(async (tx) => {
      const row = await tx.personalReminder.update({
        where: { id },
        data: {
          name: dto.name ?? current.name,
          description: dto.description === undefined ? current.description : dto.description || null,
          scheduleTimes: dto.scheduleTimes ? JSON.stringify(dto.scheduleTimes) : current.scheduleTimes,
          intervalDays: dto.intervalDays ?? current.intervalDays,
          endDate,
        },
      });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'personal_reminder.update',
          entityType: 'personal_reminder',
          entityId: id,
          after: { intervalDays: row.intervalDays, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
      return row;
    });
    await this.caregivers.notifyMember(acting, 'reminder_updated', `${id}:${now.getTime()}`);
    return presentPersonalReminder(saved);
  }

  async remove(acting: ActingFor, id: string) {
    await this.own(acting.subjectId, id);
    await this.prisma.$transaction(async (tx) => {
      await tx.personalReminder.update({ where: { id }, data: { active: false } });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'personal_reminder.remove',
          entityType: 'personal_reminder',
          entityId: id,
          after: { active: false, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
    });
    await this.caregivers.notifyMember(acting, 'reminder_removed', id);
    return { id, active: false };
  }

  /**
   * The member pressed Later. On a reminder their caregiver set up, the
   * caregiver hears about it, once per ring ([at]). Never fails the action.
   */
  async later(userId: string, id: string, at?: string) {
    const reminder = await this.own(userId, id);
    if (!reminder.createdById || reminder.createdById === userId) return { notified: false };
    try {
      const caregiver = await this.caregivers.caregiverOf(userId);
      if (!caregiver) return { notified: false };
      const copy = messages.personalReminderLater(caregiver.languagePreference, caregiver.memberName);
      await this.notifications.notify([
        {
          userId: caregiver.id,
          type: NotificationType.SYSTEM,
          title: copy.title,
          body: copy.body,
          relatedEntityId: `prlater:${id}:${at ?? new Date().toISOString().slice(0, 16)}`,
          data: { kind: 'personal_reminder_later', memberUserId: userId },
        },
      ]);
      return { notified: true };
    } catch (err) {
      this.logger.warn(`Later alert failed: ${(err as Error).message}`);
      return { notified: false };
    }
  }

  private async own(userId: string, id: string) {
    const row = await this.prisma.personalReminder.findUnique({ where: { id } });
    if (!row || row.userId !== userId || !row.active) throw new NotFoundException('Reminder not found');
    return row;
  }
}
