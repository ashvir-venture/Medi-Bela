import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { DoseStatus, MedicineRoutine, Prisma, RoutineSource } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { CatalogService } from '../catalog/catalog.service';
import { ActingFor, CaregiverAccessService } from '../family/caregiver-access.service';
import { addAppDays, startOfAppDay } from '../common/utils/time.util';
import {
  dosesForDays,
  generationLimit,
  parseScheduleTimes,
  planSchedule,
} from '../prescriptions/lib/routine-generation.service';
import { CreateRoutineDto, UpdateRoutineDto } from './dto/routine.dto';

type Who = 'YOU' | 'CAREGIVER' | null;

function who(actorId: string | null, userId: string): Who {
  if (!actorId) return null;
  return actorId === userId ? 'YOU' : 'CAREGIVER';
}

/**
 * Labels the app shows ("Self-added", "Edited by you", "by caregiver");
 * the ids of who acted are not sent.
 */
export function presentRoutine<
  T extends Pick<MedicineRoutine, 'userId' | 'source' | 'createdById' | 'lastEditedById'>,
>(routine: T) {
  const { createdById, lastEditedById, ...rest } = routine;
  return {
    ...rest,
    selfAdded: routine.source === RoutineSource.SELF_ADDED,
    addedBy: who(createdById, routine.userId),
    editedBy: who(lastEditedById, routine.userId),
  };
}

/** Readable text kept on the routine for older app screens. */
function describe(input: {
  strength?: string | null;
  doseAmount?: string | null;
  timesPerDay: number;
  mealName?: string | null;
}) {
  const dosage = [input.strength, input.doseAmount].filter(Boolean).join(', ') || '-';
  const times = `${input.timesPerDay} ${input.timesPerDay === 1 ? 'time' : 'times'} a day`;
  return { dosage, frequency: [times, input.mealName].filter(Boolean).join(', ') };
}

function dateOnly(value: string): Date {
  return new Date(`${value}T00:00:00.000Z`);
}

/**
 * Self-added medicines, and the patient-side edits/removal of any routine.
 * Every change is audited; a caregiver acting for a member also notifies
 * that member.
 */
@Injectable()
export class RoutineManagementService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly catalog: CatalogService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  async listRoutines(userId: string) {
    const routines = await this.prisma.medicineRoutine.findMany({
      where: { userId, active: true },
      orderBy: { startDate: 'asc' },
      include: { mealTiming: true },
    });
    return routines.map(presentRoutine);
  }

  async createRoutine(acting: ActingFor, dto: CreateRoutineDto) {
    if (dto.scheduleTimes.length !== dto.timesPerDay) {
      throw new BadRequestException(`Choose exactly ${dto.timesPerDay} dose time(s)`);
    }
    if (!dto.continuous && !dto.durationDays) {
      throw new BadRequestException('Give the number of days, or mark it continuous');
    }
    const now = new Date();
    if (dto.startDate && startOfAppDay(dateOnly(dto.startDate)) < startOfAppDay(now)) {
      throw new BadRequestException("The start date can't be in the past");
    }
    const mealName = await this.mealName(dto.mealTimingId);
    if (dto.medicineId) {
      const exists = await this.prisma.medicine.findUnique({ where: { id: dto.medicineId }, select: { id: true } });
      if (!exists) throw new BadRequestException('Medicine not found');
    }

    const plan = planSchedule(
      {
        scheduleTimes: dto.scheduleTimes,
        startDate: dto.startDate ? dateOnly(dto.startDate) : null,
        durationDays: dto.continuous ? null : dto.durationDays ?? null,
        continuous: dto.continuous ?? false,
      },
      now,
    );
    const text = describe({ ...dto, mealName });

    const routine = await this.prisma.$transaction(async (tx) => {
      // A typed name goes into the catalog for pharmacists to complete.
      if (!dto.medicineId) await this.catalog.findOrCreateMedicineStub(acting.actorId, dto.medicineName, tx);
      const created = await tx.medicineRoutine.create({
        data: {
          userId: acting.subjectId,
          medicineName: dto.medicineName,
          dosage: text.dosage,
          frequency: text.frequency,
          startDate: plan.startDate,
          endDate: plan.endDate,
          active: true,
          source: RoutineSource.SELF_ADDED,
          strength: dto.strength || null,
          doseAmount: dto.doseAmount || null,
          mealTimingId: dto.mealTimingId ?? null,
          scheduleTimes: JSON.stringify(dto.scheduleTimes),
          generatedUntil: plan.generatedUntil,
          createdById: acting.actorId,
        },
        include: { mealTiming: true },
      });
      await tx.medicineDose.createMany({
        data: plan.doses.map((d) => ({ routineId: created.id, userId: acting.subjectId, scheduledAt: d.scheduledAt })),
      });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'routine.create',
          entityType: 'routine',
          entityId: created.id,
          after: { medicineName: created.medicineName, scheduleTimes: dto.scheduleTimes, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
      return created;
    });

    await this.caregivers.notifyMember(acting, 'routine_added', routine.id);
    return presentRoutine(routine);
  }

  async updateRoutine(acting: ActingFor, routineId: string, dto: UpdateRoutineDto) {
    const routine = await this.ownActiveRoutine(acting.subjectId, routineId);
    const fromPrescription = routine.source === RoutineSource.PRESCRIPTION;
    const currentTimes = parseScheduleTimes(routine.scheduleTimes);

    if (fromPrescription) {
      const pharmacistFields = ['medicineName', 'strength', 'doseAmount', 'timesPerDay', 'durationDays', 'continuous'] as const;
      if (pharmacistFields.some((f) => dto[f] !== undefined)) {
        throw new BadRequestException(
          "Only dose times and meal timing can be changed on a pharmacist's medicine",
        );
      }
    }
    if (currentTimes.length === 0) {
      // Routines from before Round 4 have every dose already; no schedule to edit.
      throw new BadRequestException('This older medicine can only be removed, not edited');
    }

    const timesPerDay = dto.timesPerDay ?? currentTimes.length;
    const times = dto.scheduleTimes ?? (dto.timesPerDay === undefined ? currentTimes : null);
    if (!times || times.length !== timesPerDay) {
      throw new BadRequestException(`Choose exactly ${timesPerDay} dose time(s)`);
    }

    // End date: only a self-added routine can change its length.
    let endDate = routine.endDate;
    if (dto.continuous === true) endDate = null;
    else if (dto.durationDays !== undefined) endDate = addAppDays(startOfAppDay(routine.startDate), dto.durationDays - 1);
    else if (dto.continuous === false && !routine.endDate) {
      throw new BadRequestException('Give the number of days when it is no longer continuous');
    }

    const mealTimingId = dto.mealTimingId === undefined ? routine.mealTimingId : dto.mealTimingId;
    const mealName = await this.mealName(mealTimingId);
    const strength = dto.strength === undefined ? routine.strength : dto.strength || null;
    const doseAmount = dto.doseAmount === undefined ? routine.doseAmount : dto.doseAmount || null;
    const text = fromPrescription
      ? { dosage: routine.dosage, frequency: describe({ timesPerDay, mealName }).frequency }
      : describe({ strength, doseAmount, timesPerDay, mealName });
    const scheduleChanged =
      JSON.stringify(times) !== JSON.stringify(currentTimes) || endDate?.getTime() !== routine.endDate?.getTime();

    const now = new Date();
    const updated = await this.prisma.$transaction(async (tx) => {
      let generatedUntil = routine.generatedUntil;
      if (scheduleChanged) {
        generatedUntil = await this.regenerateFutureDoses(tx, routine, times, endDate, now);
      }
      const saved = await tx.medicineRoutine.update({
        where: { id: routine.id },
        data: {
          medicineName: dto.medicineName ?? routine.medicineName,
          strength,
          doseAmount,
          dosage: text.dosage,
          frequency: text.frequency,
          mealTimingId,
          scheduleTimes: JSON.stringify(times),
          endDate,
          generatedUntil,
          lastEditedById: acting.actorId,
          lastEditedAt: now,
        },
        include: { mealTiming: true },
      });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'routine.update',
          entityType: 'routine',
          entityId: routine.id,
          before: { scheduleTimes: currentTimes, mealTimingId: routine.mealTimingId, endDate: routine.endDate?.toISOString() ?? null },
          after: { scheduleTimes: times, mealTimingId, endDate: endDate?.toISOString() ?? null, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
      return saved;
    });

    await this.caregivers.notifyMember(acting, 'routine_updated', `${routine.id}:${now.getTime()}`);
    return presentRoutine(updated);
  }

  /** Stops a medicine: no more future doses or reminders; history is kept. */
  async removeRoutine(acting: ActingFor, routineId: string) {
    const routine = await this.ownActiveRoutine(acting.subjectId, routineId);
    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      await tx.medicineDose.deleteMany({
        where: { routineId: routine.id, status: DoseStatus.PENDING, scheduledAt: { gte: now } },
      });
      await tx.medicineRoutine.update({
        where: { id: routine.id },
        data: { active: false, lastEditedById: acting.actorId, lastEditedAt: now },
      });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'routine.remove',
          entityType: 'routine',
          entityId: routine.id,
          before: { medicineName: routine.medicineName, active: true },
          after: { active: false, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
    });
    await this.caregivers.notifyMember(acting, 'routine_removed', routine.id);
    return { id: routine.id, active: false };
  }

  // ---------------------------------------------------------------------

  private async ownActiveRoutine(userId: string, routineId: string) {
    const routine = await this.prisma.medicineRoutine.findUnique({ where: { id: routineId } });
    // Someone else's routine is the same 404 as a missing one.
    if (!routine || routine.userId !== userId || !routine.active) {
      throw new NotFoundException('Medicine not found');
    }
    return routine;
  }

  private async mealName(mealTimingId: number | null | undefined) {
    if (!mealTimingId) return null;
    const meal = await this.prisma.mealTiming.findUnique({ where: { id: mealTimingId } });
    if (!meal) throw new BadRequestException('Unknown meal timing');
    return meal.name;
  }

  /**
   * Replaces the routine's future PENDING doses with ones on the new
   * schedule. Past doses, and future ones already taken, are kept (no
   * second dose at a time already marked). Returns the new generatedUntil.
   */
  private async regenerateFutureDoses(
    tx: Prisma.TransactionClient,
    routine: MedicineRoutine,
    times: string[],
    endDate: Date | null,
    now: Date,
  ) {
    await tx.medicineDose.deleteMany({
      where: { routineId: routine.id, status: DoseStatus.PENDING, scheduledAt: { gte: now } },
    });
    const kept = await tx.medicineDose.findMany({
      where: { routineId: routine.id, scheduledAt: { gte: now } },
      select: { scheduledAt: true },
    });
    const keptTimes = new Set(kept.map((d) => d.scheduledAt.getTime()));

    const today = startOfAppDay(now);
    const start = startOfAppDay(routine.startDate);
    const from = start > today ? start : today;
    const limit = generationLimit(endDate, now);
    const until = limit > from ? limit : from;
    const doses = dosesForDays(times, from, until).filter(
      (d) => d.scheduledAt >= now && !keptTimes.has(d.scheduledAt.getTime()),
    );
    if (doses.length) {
      await tx.medicineDose.createMany({
        data: doses.map((d) => ({ routineId: routine.id, userId: routine.userId, scheduledAt: d.scheduledAt })),
      });
    }
    return until;
  }
}
