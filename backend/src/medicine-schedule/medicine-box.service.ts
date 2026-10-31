import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { DoseStatus, NotificationType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import { ActingFor, CaregiverAccessService } from '../family/caregiver-access.service';
import { remainingUnits, unitsPerDose } from './lib/dose-units';
import { SaveMedicineBoxDto } from './dto/medicine-box.dto';

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
        select: { id: true, medicineName: true, dosage: true, doseAmount: true, stock: true, form: true },
      }),
    ]);
    const items = await Promise.all(
      routines.map(async (r) => {
        const perDose = unitsPerDose(r.doseAmount);
        if (!r.stock) {
          return { ...this.base(r), unitsPerDose: perDose, quantity: null, countedAt: null, remaining: null, dosesLeft: null };
        }
        const taken = await this.prisma.medicineDose.count({
          where: { routineId: r.id, status: DoseStatus.TAKEN, takenAt: { gte: r.stock.countedAt } },
        });
        const remaining = remainingUnits(r.stock.quantity, perDose, taken);
        return {
          ...this.base(r),
          unitsPerDose: perDose,
          quantity: r.stock.quantity,
          countedAt: r.stock.countedAt,
          remaining,
          dosesLeft: Math.floor(remaining / perDose + 1e-9),
        };
      }),
    );
    return { startedAt: user?.medicineBoxStartedAt ?? null, items };
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
            countedAt: now,
            updatedById: acting.actorId,
          },
          update: { quantity: item.quantity, countedAt: now, updatedById: acting.actorId },
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

  private base(r: { id: string; medicineName: string; dosage: string; doseAmount: string | null; form: { name: string } | null }) {
    return {
      routineId: r.id,
      medicineName: r.medicineName,
      dosage: r.dosage,
      doseAmount: r.doseAmount,
      formName: r.form?.name ?? null,
    };
  }
}
