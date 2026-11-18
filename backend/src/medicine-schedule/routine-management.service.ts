import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { DoseStatus, MedicineRoutine, NotificationType, Prisma, RoutineSource } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { CatalogService } from '../catalog/catalog.service';
import { ActingFor, CaregiverAccessService } from '../family/caregiver-access.service';
import { addAppDays, appDayBounds, startOfAppDay } from '../common/utils/time.util';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import {
  dosesForDays,
  generationLimit,
  parseScheduleTimes,
  parseWeekdays,
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
  const { createdById, lastEditedById, ...rest } = routine as T & { weekdays?: string | null; packPhotoUrl?: string | null };
  // Round 18: weekdays as numbers; the pack photo's private reference never
  // leaves the server (the medicine page asks for a signed link).
  const { weekdays, packPhotoUrl, ...shown } = rest as typeof rest & { weekdays?: string | null; packPhotoUrl?: string | null };
  return {
    ...shown,
    weekdays: parseWeekdays(weekdays),
    hasPackPhoto: !!packPhotoUrl,
    selfAdded: routine.source === RoutineSource.SELF_ADDED,
    addedBy: who(createdById, routine.userId),
    editedBy: who(lastEditedById, routine.userId),
  };
}

/** Readable text kept on the routine for older app screens. */
export function describe(input: {
  strength?: string | null;
  doseAmount?: string | null;
  timesPerDay: number;
  intervalDays?: number;
  mealName?: string | null;
  weekdays?: number[];
  asNeeded?: boolean;
  maxPerDay?: number | null;
}) {
  const dosage = [input.strength, input.doseAmount].filter(Boolean).join(', ') || '-';
  if (input.asNeeded) {
    const most = input.maxPerDay ? `, at most ${input.maxPerDay} a day` : '';
    return { dosage, frequency: `as needed${most}` };
  }
  const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const every = input.weekdays?.length
    ? `on ${input.weekdays.map((d) => names[d]).join(', ')}`
    : input.intervalDays && input.intervalDays > 1
      ? `every ${input.intervalDays} days`
      : 'a day';
  const times = `${input.timesPerDay} ${input.timesPerDay === 1 ? 'time' : 'times'} ${every}`;
  return { dosage, frequency: [times, input.mealName].filter(Boolean).join(', ') };
}

/** Round 18: weekdays 0-6, unique and sorted; all seven = every day ([]). */
function normalizeWeekdays(days: number[] | null | undefined): number[] {
  const set = [...new Set(days ?? [])].filter((d) => d >= 0 && d <= 6).sort();
  return set.length === 7 ? [] : set;
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
    private readonly notifications: NotificationsService,
  ) {}

  async listRoutines(userId: string) {
    const routines = await this.prisma.medicineRoutine.findMany({
      where: { userId, active: true },
      orderBy: { startDate: 'asc' },
      include: { mealTiming: true, form: true },
    });
    // Round 18: an as-needed medicine carries the times it was taken today.
    const prn = routines.filter((r) => r.asNeeded).map((r) => r.id);
    const { start, end } = appDayBounds(new Date());
    const taken = prn.length
      ? await this.prisma.medicineDose.findMany({
          where: { routineId: { in: prn }, status: DoseStatus.TAKEN, scheduledAt: { gte: start, lt: end } },
          orderBy: { scheduledAt: 'asc' },
          select: { routineId: true, takenAt: true, scheduledAt: true },
        })
      : [];
    return routines.map((r) => ({
      ...presentRoutine(r),
      ...(r.asNeeded
        ? { takenToday: taken.filter((t) => t.routineId === r.id).map((t) => (t.takenAt ?? t.scheduledAt).toISOString()) }
        : {}),
    }));
  }

  async createRoutine(acting: ActingFor, dto: CreateRoutineDto) {
    const asNeeded = dto.asNeeded === true;
    const weekdays = normalizeWeekdays(dto.weekdays);
    if (!asNeeded && dto.scheduleTimes.length !== dto.timesPerDay) {
      throw new BadRequestException(`Choose exactly ${dto.timesPerDay} dose time(s)`);
    }
    // An as-needed medicine with no length runs until removed.
    if (!asNeeded && !dto.continuous && !dto.durationDays) {
      throw new BadRequestException('Give the number of days, or mark it continuous');
    }
    if (weekdays.length && (dto.intervalDays ?? 1) > 1) {
      throw new BadRequestException('Choose certain days or every few days, not both');
    }
    const now = new Date();
    if (dto.startDate && startOfAppDay(dateOnly(dto.startDate)) < startOfAppDay(now)) {
      throw new BadRequestException("The start date can't be in the past");
    }
    const mealName = await this.mealName(dto.mealTimingId);
    await this.assertForm(dto.formId);
    if (dto.medicineId) {
      const exists = await this.prisma.medicine.findUnique({ where: { id: dto.medicineId }, select: { id: true } });
      if (!exists) throw new BadRequestException('Medicine not found');
    }

    const plan = planSchedule(
      {
        // Round 18: an as-needed medicine has no times, so no doses.
        scheduleTimes: asNeeded ? [] : dto.scheduleTimes,
        startDate: dto.startDate ? dateOnly(dto.startDate) : null,
        durationDays: dto.continuous || (asNeeded && !dto.durationDays) ? null : dto.durationDays ?? null,
        continuous: dto.continuous ?? asNeeded,
        intervalDays: dto.intervalDays ?? 1,
        weekdays,
      },
      now,
    );
    const text = describe({ ...dto, timesPerDay: asNeeded ? 0 : dto.timesPerDay, mealName, weekdays, asNeeded });

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
          formId: dto.formId ?? null,
          conditionCode: await this.checkCondition(dto.conditionCode),
          intervalDays: dto.intervalDays ?? 1,
          weekdays: weekdays.length ? JSON.stringify(weekdays) : null,
          asNeeded,
          maxPerDay: asNeeded ? dto.maxPerDay ?? null : null,
          minGapHours: asNeeded ? dto.minGapHours ?? null : null,
          pillColor: dto.pillColor ?? null,
          pillShape: dto.pillColor ? dto.pillShape ?? null : null,
          note: dto.note || null,
          // As needed: nothing for the rolling job to extend.
          scheduleTimes: asNeeded ? null : JSON.stringify(dto.scheduleTimes),
          generatedUntil: asNeeded ? null : plan.generatedUntil,
          createdById: acting.actorId,
        },
        include: { mealTiming: true, form: true },
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
          after: {
            medicineName: created.medicineName,
            scheduleTimes: asNeeded ? [] : dto.scheduleTimes,
            weekdays,
            asNeeded,
            byCaregiver: acting.byCaregiver,
          },
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

    // Round 18: the tablet's look and the user's note are personal labels,
    // allowed on any medicine, even with nothing else changing.
    const personal = {
      pillColor: dto.pillColor === undefined ? routine.pillColor : dto.pillColor,
      pillShape: dto.pillShape === undefined ? routine.pillShape : dto.pillShape,
      note: dto.note === undefined ? routine.note : dto.note || null,
    };
    if (!personal.pillColor) personal.pillShape = null;
    const scheduleKeys = Object.keys(dto).filter((k) => !['pillColor', 'pillShape', 'note'].includes(k) && (dto as any)[k] !== undefined);
    if (scheduleKeys.length === 0) return this.savePersonal(acting, routine, personal);

    if (fromPrescription && ['asNeeded', 'maxPerDay', 'minGapHours'].some((k) => (dto as any)[k] !== undefined)) {
      throw new BadRequestException("Only dose times, meal timing and the days can be changed on a pharmacist's medicine");
    }
    const asNeeded = dto.asNeeded ?? routine.asNeeded;
    if (asNeeded) return this.saveAsNeeded(acting, routine, dto, personal);

    if (fromPrescription) {
      const pharmacistFields = [
        'medicineName',
        'strength',
        'doseAmount',
        'timesPerDay',
        'durationDays',
        'continuous',
        'formId',
      ] as const;
      if (pharmacistFields.some((f) => dto[f] !== undefined)) {
        throw new BadRequestException(
          "Only dose times, meal timing and every N days can be changed on a pharmacist's medicine",
        );
      }
    }
    if (currentTimes.length === 0 && !routine.asNeeded) {
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
    const formId = dto.formId === undefined ? routine.formId : dto.formId;
    await this.assertForm(dto.formId);
    const weekdays = dto.weekdays === undefined ? parseWeekdays(routine.weekdays) : normalizeWeekdays(dto.weekdays);
    // Picking "every few days" clears certain days, and the other way round.
    const intervalDays = dto.intervalDays ?? (dto.weekdays?.length ? 1 : routine.intervalDays);
    if (weekdays.length && intervalDays > 1) {
      throw new BadRequestException('Choose certain days or every few days, not both');
    }
    const strength = dto.strength === undefined ? routine.strength : dto.strength || null;
    const doseAmount = dto.doseAmount === undefined ? routine.doseAmount : dto.doseAmount || null;
    const text = fromPrescription
      ? { dosage: routine.dosage, frequency: describe({ timesPerDay, intervalDays, mealName, weekdays }).frequency }
      : describe({ strength, doseAmount, timesPerDay, intervalDays, mealName, weekdays });
    const scheduleChanged =
      routine.asNeeded ||
      JSON.stringify(times) !== JSON.stringify(currentTimes) ||
      endDate?.getTime() !== routine.endDate?.getTime() ||
      intervalDays !== routine.intervalDays ||
      JSON.stringify(weekdays) !== JSON.stringify(parseWeekdays(routine.weekdays));

    const now = new Date();
    const updated = await this.prisma.$transaction(async (tx) => {
      let generatedUntil = routine.generatedUntil;
      if (scheduleChanged) {
        generatedUntil = await this.regenerateFutureDoses(tx, routine, times, endDate, intervalDays, now, weekdays);
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
          formId,
          intervalDays,
          weekdays: weekdays.length ? JSON.stringify(weekdays) : null,
          asNeeded: false,
          maxPerDay: null,
          minGapHours: null,
          ...personal,
          scheduleTimes: JSON.stringify(times),
          endDate,
          generatedUntil,
          lastEditedById: acting.actorId,
          lastEditedAt: now,
        },
        include: { mealTiming: true, form: true },
      });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'routine.update',
          entityType: 'routine',
          entityId: routine.id,
          before: {
            scheduleTimes: currentTimes,
            mealTimingId: routine.mealTimingId,
            intervalDays: routine.intervalDays,
            endDate: routine.endDate?.toISOString() ?? null,
          },
          after: {
            scheduleTimes: times,
            mealTimingId,
            intervalDays,
            endDate: endDate?.toISOString() ?? null,
            byCaregiver: acting.byCaregiver,
          },
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

  /**
   * Round 18 ("Took one now"): logs an as-needed medicine as a TAKEN dose at
   * [takenAt] (the tap, also when synced later; never in the future, at most
   * a day back). Going over the daily most or inside the minimum gap only
   * warns; over the most, the caregiver is told once that day (neutral text).
   */
  async takeAsNeeded(acting: ActingFor, routineId: string, takenAtIso?: string) {
    const routine = await this.ownActiveRoutine(acting.subjectId, routineId);
    if (!routine.asNeeded) throw new BadRequestException('This medicine has set times; mark its dose instead');
    const now = new Date();
    let takenAt = takenAtIso ? new Date(takenAtIso) : now;
    if (Number.isNaN(takenAt.getTime()) || takenAt > now) takenAt = now;
    if (now.getTime() - takenAt.getTime() > 86_400_000) throw new BadRequestException('Too long ago to log');

    const { start, end } = appDayBounds(takenAt);
    const result = await this.prisma.$transaction(async (tx) => {
      // The same tap synced twice (offline queue retry) is one dose.
      const same = await tx.medicineDose.findFirst({ where: { routineId, scheduledAt: takenAt } });
      const dose =
        same ??
        (await tx.medicineDose.create({
          data: {
            routineId,
            userId: acting.subjectId,
            scheduledAt: takenAt,
            status: DoseStatus.TAKEN,
            takenAt,
            takenById: acting.byCaregiver ? acting.actorId : null,
          },
        }));
      const today = await tx.medicineDose.findMany({
        where: { routineId, status: DoseStatus.TAKEN, scheduledAt: { gte: start, lt: end } },
        orderBy: { scheduledAt: 'asc' },
        select: { id: true, takenAt: true, scheduledAt: true },
      });
      if (acting.byCaregiver && !same) {
        await this.audit.record(
          {
            actorId: acting.actorId,
            subjectUserId: acting.subjectId,
            action: 'dose.give',
            entityType: 'dose',
            entityId: dose.id,
            after: { asNeeded: true, byCaregiver: true },
          },
          tx,
        );
      }
      return { dose, today };
    });

    const count = result.today.length;
    const previous = result.today.filter((d) => d.id !== result.dose.id).map((d) => (d.takenAt ?? d.scheduledAt).getTime());
    const lastBefore = previous.filter((t) => t <= takenAt.getTime()).sort((a, b) => b - a)[0];
    const overMax = routine.maxPerDay != null && count > routine.maxPerDay;
    const tooSoon =
      routine.minGapHours != null && lastBefore != null && takenAt.getTime() - lastBefore < routine.minGapHours * 3_600_000;
    if (overMax) await this.tellCaregiverOverMax(acting.subjectId, routineId, start);
    if (acting.byCaregiver) await this.caregivers.notifyMember(acting, 'dose_given', result.dose.id, { doseIds: result.dose.id });
    return {
      doseId: result.dose.id,
      takenAt: (result.dose.takenAt ?? takenAt).toISOString(),
      takenToday: result.today.map((d) => (d.takenAt ?? d.scheduledAt).toISOString()),
      overMax,
      tooSoon,
    };
  }

  private async tellCaregiverOverMax(memberId: string, routineId: string, day: Date) {
    const caregiver = await this.caregivers.caregiverOf(memberId);
    if (!caregiver) return;
    const copy = messages.asNeededOverMaxCaregiver(caregiver.languagePreference, caregiver.memberName);
    await this.notifications.notify([
      {
        userId: caregiver.id,
        type: NotificationType.MISSED_DOSE_FAMILY_ALERT,
        title: copy.title,
        body: copy.body,
        // Once per medicine per day.
        relatedEntityId: `prn-over:${routineId}:${day.toISOString().slice(0, 10)}`,
        data: { kind: 'as_needed_over_max', memberId },
      },
    ]);
  }

  /** Round 18: only the tablet look / note changed (any medicine, even an older one). */
  private async savePersonal(
    acting: ActingFor,
    routine: MedicineRoutine,
    personal: { pillColor: string | null; pillShape: string | null; note: string | null },
  ) {
    const now = new Date();
    const saved = await this.prisma.$transaction(async (tx) => {
      const row = await tx.medicineRoutine.update({
        where: { id: routine.id },
        data: { ...personal, lastEditedById: acting.actorId, lastEditedAt: now },
        include: { mealTiming: true, form: true },
      });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'routine.update',
          entityType: 'routine',
          entityId: routine.id,
          before: { pillColor: routine.pillColor, pillShape: routine.pillShape, hasNote: !!routine.note },
          after: { pillColor: personal.pillColor, pillShape: personal.pillShape, hasNote: !!personal.note, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
      return row;
    });
    await this.caregivers.notifyMember(acting, 'routine_updated', `${routine.id}:${now.getTime()}`);
    return presentRoutine(saved);
  }

  /**
   * Round 18: a self-added medicine that is (or becomes) "only when needed":
   * no times and no future doses; the days it was taken stay in history.
   */
  private async saveAsNeeded(
    acting: ActingFor,
    routine: MedicineRoutine,
    dto: UpdateRoutineDto,
    personal: { pillColor: string | null; pillShape: string | null; note: string | null },
  ) {
    let endDate = routine.endDate;
    if (dto.continuous === true) endDate = null;
    else if (dto.durationDays !== undefined) endDate = addAppDays(startOfAppDay(routine.startDate), dto.durationDays - 1);
    const mealTimingId = dto.mealTimingId === undefined ? routine.mealTimingId : dto.mealTimingId;
    await this.mealName(mealTimingId);
    await this.assertForm(dto.formId);
    const maxPerDay = dto.maxPerDay === undefined ? routine.maxPerDay : dto.maxPerDay;
    const minGapHours = dto.minGapHours === undefined ? routine.minGapHours : dto.minGapHours;
    const strength = dto.strength === undefined ? routine.strength : dto.strength || null;
    const doseAmount = dto.doseAmount === undefined ? routine.doseAmount : dto.doseAmount || null;
    const text = describe({ strength, doseAmount, timesPerDay: 0, asNeeded: true, maxPerDay });
    const now = new Date();
    const saved = await this.prisma.$transaction(async (tx) => {
      await tx.medicineDose.deleteMany({ where: { routineId: routine.id, status: DoseStatus.PENDING, scheduledAt: { gte: now } } });
      const row = await tx.medicineRoutine.update({
        where: { id: routine.id },
        data: {
          medicineName: dto.medicineName ?? routine.medicineName,
          strength,
          doseAmount,
          dosage: text.dosage,
          frequency: text.frequency,
          mealTimingId,
          formId: dto.formId === undefined ? routine.formId : dto.formId,
          asNeeded: true,
          maxPerDay,
          minGapHours,
          weekdays: null,
          intervalDays: 1,
          scheduleTimes: null,
          generatedUntil: null,
          endDate,
          ...personal,
          lastEditedById: acting.actorId,
          lastEditedAt: now,
        },
        include: { mealTiming: true, form: true },
      });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'routine.update',
          entityType: 'routine',
          entityId: routine.id,
          before: { asNeeded: routine.asNeeded, scheduleTimes: parseScheduleTimes(routine.scheduleTimes) },
          after: { asNeeded: true, maxPerDay, minGapHours, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
      return row;
    });
    await this.caregivers.notifyMember(acting, 'routine_updated', `${routine.id}:${now.getTime()}`);
    return presentRoutine(saved);
  }

  private async ownActiveRoutine(userId: string, routineId: string) {
    const routine = await this.prisma.medicineRoutine.findUnique({ where: { id: routineId } });
    // Someone else's routine is the same 404 as a missing one.
    if (!routine || routine.userId !== userId || !routine.active) {
      throw new NotFoundException('Medicine not found');
    }
    return routine;
  }

  private async assertForm(formId: number | null | undefined) {
    if (!formId) return;
    const form = await this.prisma.medicineForm.findUnique({ where: { id: formId }, select: { id: true } });
    if (!form) throw new BadRequestException('Unknown medicine form');
  }

  /** Round 16: tag (or untag) any active medicine with a condition. */
  async setCondition(acting: ActingFor, id: string, conditionCode: string | null) {
    const routine = await this.prisma.medicineRoutine.findUnique({ where: { id } });
    if (!routine || routine.userId !== acting.subjectId || !routine.active) throw new NotFoundException('Medicine not found');
    const code = await this.checkCondition(conditionCode);
    const saved = await this.prisma.$transaction(async (tx) => {
      const row = await tx.medicineRoutine.update({
        where: { id },
        data: { conditionCode: code },
        include: { mealTiming: true, form: true },
      });
      await this.audit.record(
        {
          actorId: acting.actorId,
          subjectUserId: acting.subjectId,
          action: 'routine.condition',
          entityType: 'routine',
          entityId: id,
          before: { conditionCode: routine.conditionCode },
          after: { conditionCode: code, byCaregiver: acting.byCaregiver },
        },
        tx,
      );
      return row;
    });
    await this.caregivers.notifyMember(acting, 'routine_updated', `${id}:condition:${Date.now()}`);
    return presentRoutine(saved);
  }

  private async checkCondition(code: string | null | undefined) {
    if (!code) return null;
    if (!(await this.prisma.condition.findUnique({ where: { code } }))) throw new BadRequestException('Unknown condition');
    return code;
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
    intervalDays: number,
    now: Date,
    weekdays: number[] = [],
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
    const doses = dosesForDays(times, from, until, { days: intervalDays, anchor: start, weekdays }).filter(
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
