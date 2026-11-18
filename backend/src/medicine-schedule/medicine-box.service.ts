import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { DoseStatus, NotificationType, StockKind } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import { ActingFor, CaregiverAccessService } from '../family/caregiver-access.service';
import { boxUnitsPerDose, remainingUnits } from './lib/dose-units';
import { parseScheduleTimes, parseWeekdays } from '../prescriptions/lib/routine-generation.service';
import { BoxExtraDto, SaveMedicineBoxDto, UpdateBoxExtraDto } from './dto/medicine-box.dto';

/**
 * Medicine box (Round 13): how many of each medicine the user has. The count
 * is set at Start / Refill (a total that replaces the old one); what is left
 * is worked out from the doses taken since, so an offline "taken" synced
 * later still counts once. The app shows the 3-doses-left notice and the
 * full-screen Refill / Ignore itself; Ignore here tells the caregiver.
 */
@Injectable()
export class MedicineBoxService {
  private readonly logger = new Logger(MedicineBoxService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  /** Every active medicine, counted or not ("Not counted yet"). */
  async get(userId: string) {
    const [user, routines] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: userId }, select: { medicineBoxStartedAt: true } }),
      this.prisma.medicineRoutine.findMany({
        where: { userId, active: true },
        orderBy: { startDate: 'asc' },
        select: {
          id: true,
          medicineName: true,
          dosage: true,
          doseAmount: true,
          stock: true,
          form: true,
          scheduleTimes: true,
          intervalDays: true,
          weekdays: true,
          asNeeded: true,
          pillColor: true,
          pillShape: true,
        },
      }),
    ]);
    const items = await Promise.all(
      routines.map(async (r) => {
        const unit = r.stock?.unit ?? defaultUnit(r.form?.name);
        const perDose = boxUnitsPerDose(r.doseAmount, unit);
        const perDay = r.asNeeded ? null : scheduledPerDay(r) * perDose;
        const refillDays = r.stock?.refillDays ?? 3;
        if (!r.stock) {
          return {
            ...this.base(r),
            unit,
            unitsPerDose: perDose,
            perDay,
            refillDays,
            quantity: null,
            countedAt: null,
            remaining: null,
            dosesLeft: null,
            daysLeft: null,
          };
        }
        const taken = await this.prisma.medicineDose.count({
          where: { routineId: r.id, status: DoseStatus.TAKEN, takenAt: { gte: r.stock.countedAt } },
        });
        const remaining = remainingUnits(r.stock.quantity, perDose, taken);
        return {
          ...this.base(r),
          unit,
          unitsPerDose: perDose,
          perDay,
          refillDays,
          quantity: r.stock.quantity,
          countedAt: r.stock.countedAt,
          remaining,
          dosesLeft: Math.floor(remaining / perDose + 1e-9),
          // Round 18: how long it lasts (client: "20 ml a day from 200 ml = 10 days").
          daysLeft: perDay ? Math.floor(remaining / perDay + 1e-9) : null,
        };
      }),
    );
    // Round 18: medicines with no reminder and care supplies.
    const extras = await this.prisma.medicineStock.findMany({
      where: { userId, routineId: null },
      orderBy: [{ kind: 'asc' }, { name: 'asc' }],
    });
    const now = Date.now();
    return {
      startedAt: user?.medicineBoxStartedAt ?? null,
      items,
      extras: extras.map((x) => {
        const days = (now - x.countedAt.getTime()) / 86_400_000;
        const remaining = x.perDay ? Math.max(0, x.quantity - x.perDay * days) : x.quantity;
        return {
          id: x.id,
          kind: x.kind,
          name: x.name,
          unit: x.unit,
          perDay: x.perDay,
          refillDays: x.refillDays ?? (x.kind === StockKind.SUPPLY ? 5 : 3),
          quantity: x.quantity,
          countedAt: x.countedAt,
          remaining: Math.round(remaining * 100) / 100,
          daysLeft: x.perDay ? Math.floor(remaining / x.perDay + 1e-9) : null,
        };
      }),
    };
  }

  /** Round 18: a box-only item (no reminder): a medicine at home or a care supply. */
  async addExtra(acting: ActingFor, dto: BoxExtraDto) {
    const now = new Date();
    const row = await this.prisma.$transaction(async (tx) => {
      const created = await tx.medicineStock.create({
        data: {
          userId: acting.subjectId,
          routineId: null,
          kind: dto.kind,
          name: dto.name,
          unit: dto.unit,
          perDay: dto.perDay ?? null,
          refillDays: dto.refillDays ?? null,
          quantity: dto.quantity,
          countedAt: now,
          updatedById: acting.actorId,
        },
      });
      await tx.user.updateMany({ where: { id: acting.subjectId, medicineBoxStartedAt: null }, data: { medicineBoxStartedAt: now } });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'medicine_box.save',
          entityType: 'medicine_box',
          entityId: created.id,
          after: { kind: dto.kind, added: true, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
      return created;
    });
    await this.caregivers.notifyMember(acting, 'medicine_box_updated', `${row.id}:${now.getTime()}`);
    return this.get(acting.subjectId);
  }

  /** Round 18: rename, change the use per day, or a new count ("Bought"). */
  async updateExtra(acting: ActingFor, id: string, dto: UpdateBoxExtraDto) {
    const row = await this.ownExtra(acting.subjectId, id);
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await tx.medicineStock.update({
        where: { id: row.id },
        data: {
          name: dto.name ?? row.name,
          unit: dto.unit ?? row.unit,
          perDay: dto.perDay === undefined ? row.perDay : dto.perDay,
          refillDays: dto.refillDays ?? row.refillDays,
          ...(dto.quantity !== undefined ? { quantity: dto.quantity, countedAt: now } : {}),
          updatedById: acting.actorId,
        },
      });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'medicine_box.save',
          entityType: 'medicine_box',
          entityId: row.id,
          after: { kind: row.kind, counted: dto.quantity !== undefined, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
    });
    await this.caregivers.notifyMember(acting, 'medicine_box_updated', `${row.id}:${now.getTime()}`);
    return this.get(acting.subjectId);
  }

  async removeExtra(acting: ActingFor, id: string) {
    const row = await this.ownExtra(acting.subjectId, id);
    await this.prisma.$transaction(async (tx) => {
      await tx.medicineStock.delete({ where: { id: row.id } });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'medicine_box.save',
          entityType: 'medicine_box',
          entityId: row.id,
          after: { kind: row.kind, removed: true, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
    });
    await this.caregivers.notifyMember(acting, 'medicine_box_updated', `${row.id}:removed`);
    return this.get(acting.subjectId);
  }

  private async ownExtra(userId: string, id: string) {
    const row = await this.prisma.medicineStock.findUnique({ where: { id } });
    if (!row || row.userId !== userId || row.routineId !== null) throw new NotFoundException('Item not found');
    return row;
  }

  /** Start the box, or Refill some medicines: totals now, counted from now. */
  async save(acting: ActingFor, dto: SaveMedicineBoxDto) {
    const ids = [...new Set(dto.items.map((i) => i.routineId))];
    if (ids.length !== dto.items.length) throw new BadRequestException('A medicine is listed twice');
    const owned = await this.prisma.medicineRoutine.count({
      where: { id: { in: ids }, userId: acting.subjectId, active: true },
    });
    if (owned !== ids.length) throw new NotFoundException('Medicine not found');
    const now = new Date();

    await this.prisma.$transaction(async (tx) => {
      for (const item of dto.items) {
        await tx.medicineStock.upsert({
          where: { routineId: item.routineId },
          create: {
            userId: acting.subjectId,
            routineId: item.routineId,
            quantity: item.quantity,
            unit: item.unit ?? null,
            refillDays: item.refillDays ?? null,
            countedAt: now,
            updatedById: acting.actorId,
          },
          update: {
            quantity: item.quantity,
            countedAt: now,
            updatedById: acting.actorId,
            ...(item.unit ? { unit: item.unit } : {}),
            ...(item.refillDays ? { refillDays: item.refillDays } : {}),
          },
        });
      }
      await tx.user.updateMany({
        where: { id: acting.subjectId, medicineBoxStartedAt: null },
        data: { medicineBoxStartedAt: now },
      });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'medicine_box.save',
          entityType: 'medicine_box',
          entityId: acting.subjectId,
          after: { medicines: dto.items.length, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
    });
    await this.caregivers.notifyMember(acting, 'medicine_box_updated', `${acting.subjectId}:${now.getTime()}`);
    return this.get(acting.subjectId);
  }

  /**
   * The member pressed Ignore on "this medicine ran out": the caregiver gets
   * a banner (no medicine name), once per count. Never fails the action.
   */
  async ignore(userId: string, routineId: string) {
    const stock = await this.prisma.medicineStock.findUnique({ where: { routineId } });
    if (!stock || stock.userId !== userId) throw new NotFoundException('Medicine not found');
    try {
      const caregiver = await this.caregivers.caregiverOf(userId);
      if (!caregiver) return { notified: false };
      const copy = messages.medicineBoxEmptyCaregiver(caregiver.languagePreference, caregiver.memberName);
      await this.notifications.notify([
        {
          userId: caregiver.id,
          type: NotificationType.SYSTEM,
          title: copy.title,
          body: copy.body,
          relatedEntityId: `stock:${routineId}:${stock.countedAt.getTime()}`,
          data: { kind: 'medicine_box_empty', memberUserId: userId },
        },
      ]);
      return { notified: true };
    } catch (err) {
      this.logger.warn(`Medicine box alert failed: ${(err as Error).message}`);
      return { notified: false };
    }
  }

  private base(r: {
    id: string;
    medicineName: string;
    dosage: string;
    doseAmount: string | null;
    form: { name: string } | null;
    asNeeded?: boolean;
    pillColor?: string | null;
    pillShape?: string | null;
  }) {
    return {
      routineId: r.id,
      medicineName: r.medicineName,
      dosage: r.dosage,
      doseAmount: r.doseAmount,
      formName: r.form?.name ?? null,
      asNeeded: r.asNeeded ?? false,
      pillColor: r.pillColor ?? null,
      pillShape: r.pillShape ?? null,
    };
  }
}

/** Round 18: a syrup is counted in ml, everything else in its own units by default. */
export function defaultUnit(formName: string | null | undefined): string {
  const f = (formName ?? '').toLowerCase();
  if (f.includes('syrup') || f.includes('suspension') || f.includes('solution')) return 'ml';
  if (f.includes('capsule')) return 'capsule';
  if (f.includes('drop')) return 'drop';
  if (f.includes('inhaler')) return 'puff';
  if (f.includes('insulin')) return 'unit';
  if (f.includes('sachet')) return 'sachet';
  if (f.includes('tablet')) return 'tablet';
  return 'dose';
}

/** Doses a day on average: times a day, every N days and certain weekdays taken into account. */
export function scheduledPerDay(r: { scheduleTimes: string | null; intervalDays: number; weekdays: string | null }): number {
  const times = parseScheduleTimes(r.scheduleTimes).length;
  if (!times) return 0;
  const days = parseWeekdays(r.weekdays);
  const share = days.length ? days.length / 7 : 1 / Math.max(1, r.intervalDays);
  return times * share;
}
