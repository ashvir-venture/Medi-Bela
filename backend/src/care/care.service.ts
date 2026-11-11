import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { CareLogKind, NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import { ActingFor, CaregiverAccessService } from '../family/caregiver-access.service';
import { appUtcOffsetMinutes } from '../common/utils/time.util';
import {
  CareSettingDto,
  CreateCareLogDto,
  CreateQuestionDto,
  SetConditionsDto,
  SetTickDto,
  TEST_EVERY_MONTHS,
  UpdateLimitsDto,
} from './dto/care.dto';

/** Fields each condition's settings may carry, on top of the care plan. */
const PLAN_FIELDS = ['habits', 'customHabits', 'tests', 'testEveryMonths'] as const;
const CONDITION_FIELDS: Record<string, readonly string[]> = {
  diabetes: ['pen'],
  pregnancy: ['dueDate', 'startWeightKg', 'birthPlan'],
  asthma: ['triggers'],
  kidney: ['dialysis', 'dialysisDays', 'dialysisTime'],
  cancer: ['chemoTotal', 'chemoDone'],
};
const CODE = /^[a-z0-9_]{1,40}$/;
const CUSTOM_HABIT_KEY = /^u_[a-z0-9]{1,20}$/;
/** Habit ticks are kept for the last 7 days (the dot strip). */
const TICK_DAYS = 7;
/** Care logs sent with the overview: the last 60 days (Td doses: all). */
const LOG_DAYS = 60;

/** The app's calendar date (YYYY-MM-DD) for [ref]. */
export function appDate(ref: Date, offsetMinutes = appUtcOffsetMinutes()): string {
  return new Date(ref.getTime() + offsetMinutes * 60_000).toISOString().slice(0, 10);
}
const dateOnly = (value: string) => new Date(`${value}T00:00:00.000Z`);
const isoDay = (d: Date) => d.toISOString().slice(0, 10);

/**
 * Round 15 "My care": the conditions a user picked, the doctor's limits,
 * per-condition settings (care plan, pen, due date, dialysis days, chemo
 * cycles...), habit / night ticks, care logs (symptom check-ins, kick
 * counts, reliever puffs, Td doses), questions for the doctor, and the
 * emergency "Alert family" button. Every write also works for the
 * caregiver (`ActingFor`): audited, the member told.
 */
@Injectable()
export class CareService {
  private readonly logger = new Logger(CareService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  /** Everything the condition pages need, in one answer (the app caches it). */
  async overview(userId: string, now = new Date()) {
    const today = dateOnly(appDate(now));
    const tickFrom = new Date(today.getTime() - (TICK_DAYS - 1) * 86_400_000);
    const logFrom = new Date(now.getTime() - LOG_DAYS * 86_400_000);
    const [user, conditions, limits, settings, ticks, logs, questions] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: userId }, select: { heightCm: true, careStepDoneAt: true } }),
      this.prisma.userCondition.findMany({
        where: { userId },
        select: { condition: { select: { code: true } } },
        orderBy: { condition: { sortOrder: 'asc' } },
      }),
      this.prisma.healthLimits.findUnique({ where: { userId } }),
      this.prisma.careSetting.findMany({ where: { userId } }),
      this.prisma.dayTick.findMany({ where: { userId, day: { gte: tickFrom } }, orderBy: { day: 'asc' } }),
      this.prisma.careLog.findMany({
        where: { userId, OR: [{ loggedAt: { gte: logFrom } }, { kind: CareLogKind.TD_DOSE }] },
        orderBy: { loggedAt: 'desc' },
        take: 500,
      }),
      this.prisma.doctorQuestion.findMany({ where: { userId }, orderBy: { createdAt: 'asc' } }),
    ]);
    if (!user) throw new NotFoundException('User not found');
    return {
      conditions: conditions.map((c) => c.condition.code),
      careStepDone: user.careStepDoneAt != null,
      heightCm: user.heightCm,
      limits: limits ? this.presentLimits(limits) : null,
      settings: Object.fromEntries(settings.map((s) => [s.conditionCode, s.data])),
      ticks: ticks.map((t) => ({ key: t.key, day: isoDay(t.day) })),
      logs: logs.map(({ enteredById, userId: _u, clientId: _c, ...l }) => ({
        ...l,
        byCaregiver: Boolean(enteredById && enteredById !== userId),
      })),
      questions: questions.map(({ createdById, userId: _u, ...q }) => ({
        ...q,
        byCaregiver: Boolean(createdById && createdById !== userId),
      })),
    };
  }

  private presentLimits(l: Prisma.HealthLimitsGetPayload<object>) {
    const { updatedById, userId, ...rest } = l;
    return { ...rest, byCaregiver: Boolean(updatedById && updatedById !== userId) };
  }

  // --- Conditions --------------------------------------------------------

  /** Replaces the picked conditions; also marks the sign-up step done. */
  async setConditions(acting: ActingFor, dto: SetConditionsDto) {
    const codes = [...new Set(dto.codes)];
    const rows = await this.prisma.condition.findMany({ where: { code: { in: codes } }, select: { id: true, code: true } });
    if (rows.length !== codes.length) throw new BadRequestException('Unknown condition');
    await this.prisma.$transaction(async (tx) => {
      await tx.userCondition.deleteMany({ where: { userId: acting.subjectId } });
      if (rows.length) {
        await tx.userCondition.createMany({ data: rows.map((r) => ({ userId: acting.subjectId, conditionId: r.id })) });
      }
      await tx.user.update({ where: { id: acting.subjectId }, data: { careStepDoneAt: new Date() } });
      await this.audited(tx, acting, 'care.conditions', 'user', acting.subjectId, { count: rows.length });
    });
    await this.tellMember(acting, 'conditions');
    return this.overview(acting.subjectId);
  }

  /** "Later" on the sign-up step: don't show it again. */
  async skipStep(userId: string) {
    await this.prisma.user.update({ where: { id: userId }, data: { careStepDoneAt: new Date() } });
    return { careStepDone: true };
  }

  // --- Limits ------------------------------------------------------------

  async updateLimits(acting: ActingFor, dto: UpdateLimitsDto) {
    const current = await this.prisma.healthLimits.findUnique({ where: { userId: acting.subjectId } });
    const merged = { ...current, ...stripUndefined(dto) } as Record<string, unknown>;
    const pair = (lo: string, hi: string, what: string) => {
      const a = merged[lo] as number | null | undefined;
      const b = merged[hi] as number | null | undefined;
      if (a != null && b != null && a >= b) throw new BadRequestException(`${what}: the lowest must be below the highest`);
    };
    pair('fastingLow', 'fastingHigh', 'Fasting sugar');
    pair('tshLow', 'tshHigh', 'TSH');
    pair('bpSystolicLow', 'bpSystolicHigh', 'Blood pressure');
    const data = { ...stripUndefined(dto), updatedById: acting.actorId };
    const saved = await this.prisma.$transaction(async (tx) => {
      const row = await tx.healthLimits.upsert({
        where: { userId: acting.subjectId },
        create: { userId: acting.subjectId, ...data },
        update: data,
      });
      // Which numbers changed, never their values.
      await this.audited(tx, acting, 'care.limits', 'health_limits', acting.subjectId, { fields: Object.keys(stripUndefined(dto)) });
      return row;
    });
    await this.tellMember(acting, 'limits');
    return this.presentLimits(saved);
  }

  // --- Settings ----------------------------------------------------------

  async updateSetting(acting: ActingFor, code: string, dto: CareSettingDto) {
    if (!CODE.test(code) || !(await this.prisma.condition.findUnique({ where: { code } }))) {
      throw new NotFoundException('Condition not found');
    }
    const sent = stripUndefined(dto as Record<string, unknown>);
    const allowed = new Set<string>([...PLAN_FIELDS, ...(CONDITION_FIELDS[code] ?? [])]);
    const extra = Object.keys(sent).filter((k) => !allowed.has(k));
    if (extra.length) throw new BadRequestException(`Not a ${code} setting: ${extra.join(', ')}`);
    checkPlan(sent);
    const current = await this.prisma.careSetting.findUnique({
      where: { userId_conditionCode: { userId: acting.subjectId, conditionCode: code } },
    });
    const merged: Record<string, unknown> = { ...(current?.data as Record<string, unknown> | undefined) };
    for (const [k, v] of Object.entries(sent)) {
      if (v === null) delete merged[k];
      else merged[k] = v;
    }
    if (typeof merged.chemoTotal === 'number' && typeof merged.chemoDone === 'number' && merged.chemoDone > merged.chemoTotal) {
      throw new BadRequestException('More cycles done than planned');
    }
    const data = merged as Prisma.InputJsonValue;
    await this.prisma.$transaction(async (tx) => {
      await tx.careSetting.upsert({
        where: { userId_conditionCode: { userId: acting.subjectId, conditionCode: code } },
        create: { userId: acting.subjectId, conditionCode: code, data, updatedById: acting.actorId },
        update: { data, updatedById: acting.actorId },
      });
      await this.audited(tx, acting, 'care.settings', 'care_setting', null, { condition: code, fields: Object.keys(sent) });
    });
    await this.tellMember(acting, `settings:${code}`);
    return { conditionCode: code, data: merged };
  }

  // --- Ticks (habit done today, asthma night) ---------------------------

  async setTick(acting: ActingFor, dto: SetTickDto, now = new Date()) {
    const today = appDate(now);
    const earliest = isoDay(new Date(dateOnly(today).getTime() - (TICK_DAYS - 1) * 86_400_000));
    if (dto.day > today || dto.day < earliest) throw new BadRequestException('Only the last 7 days can be ticked');
    const where = { userId: acting.subjectId, key: dto.key, day: dateOnly(dto.day) };
    if (dto.done) {
      await this.prisma.dayTick.upsert({
        where: { userId_key_day: where },
        create: where,
        update: {},
      });
    } else {
      await this.prisma.dayTick.deleteMany({ where });
    }
    return { key: dto.key, day: dto.day, done: dto.done };
  }

  // --- Care logs ---------------------------------------------------------

  async createLog(acting: ActingFor, dto: CreateCareLogDto) {
    const data = checkLogData(dto);
    if (dto.clientId) {
      const existing = await this.prisma.careLog.findUnique({
        where: { userId_clientId: { userId: acting.subjectId, clientId: dto.clientId } },
      });
      if (existing) return this.presentLog(existing);
    }
    const row = await this.prisma.careLog.create({
      data: {
        userId: acting.subjectId,
        kind: dto.kind,
        conditionCode: dto.conditionCode ?? null,
        loggedAt: dto.loggedAt ? new Date(dto.loggedAt) : new Date(),
        data: data as Prisma.InputJsonValue,
        clientId: dto.clientId ?? null,
        enteredById: acting.byCaregiver ? acting.actorId : null,
      },
    });
    if (acting.byCaregiver) {
      await this.audit.record({
        actorId: acting.actorId,
        subjectUserId: acting.subjectId,
        action: 'care.log',
        entityType: 'care_log',
        entityId: row.id,
        after: { kind: row.kind, byCaregiver: true },
      });
      await this.tellMember(acting, `log:${row.id}`);
    }
    return this.presentLog(row);
  }

  async deleteLog(acting: ActingFor, id: string) {
    const row = await this.prisma.careLog.findUnique({ where: { id } });
    if (!row || row.userId !== acting.subjectId) throw new NotFoundException('Entry not found');
    await this.prisma.careLog.delete({ where: { id } });
    if (acting.byCaregiver) {
      await this.audit.record({
        actorId: acting.actorId,
        subjectUserId: acting.subjectId,
        action: 'care.log_delete',
        entityType: 'care_log',
        entityId: id,
        before: { kind: row.kind },
      });
    }
    return { deleted: true };
  }

  private presentLog(l: Prisma.CareLogGetPayload<object>) {
    const { enteredById, userId, clientId: _c, ...rest } = l;
    return { ...rest, byCaregiver: Boolean(enteredById && enteredById !== userId) };
  }

  // --- Questions for my doctor ------------------------------------------

  async addQuestion(acting: ActingFor, dto: CreateQuestionDto) {
    const count = await this.prisma.doctorQuestion.count({ where: { userId: acting.subjectId } });
    if (count >= 50) throw new BadRequestException('Up to 50 questions');
    const row = await this.prisma.doctorQuestion.create({
      data: { userId: acting.subjectId, text: dto.text, createdById: acting.actorId },
    });
    await this.tellMember(acting, `question:${row.id}`);
    return { id: row.id, text: row.text, createdAt: row.createdAt, byCaregiver: acting.byCaregiver };
  }

  async deleteQuestion(acting: ActingFor, id: string) {
    const row = await this.prisma.doctorQuestion.findUnique({ where: { id } });
    if (!row || row.userId !== acting.subjectId) throw new NotFoundException('Question not found');
    await this.prisma.doctorQuestion.delete({ where: { id } });
    return { deleted: true };
  }

  // --- Emergency: "Alert family" ----------------------------------------

  /**
   * The member pressed "Alert family" on an emergency sheet: one neutral
   * push to their caregiver (nobody when they are the caregiver). At most
   * one per minute, so a double tap sends one.
   */
  async alertFamily(userId: string, now = new Date()) {
    const caregiver = await this.caregivers.caregiverOf(userId);
    if (!caregiver) return { notified: false };
    const copy = messages.helpAlertCaregiver(caregiver.languagePreference, caregiver.memberName);
    try {
      await this.notifications.notify([
        {
          userId: caregiver.id,
          type: NotificationType.SYSTEM,
          title: copy.title,
          body: copy.body,
          relatedEntityId: `help:${userId}:${Math.floor(now.getTime() / 60_000)}`,
          data: { kind: 'help_alert', memberUserId: userId },
        },
      ]);
    } catch (err) {
      this.logger.warn(`Help alert failed: ${(err as Error).message}`);
      return { notified: false };
    }
    return { notified: true };
  }

  // --- helpers -----------------------------------------------------------

  private async audited(
    tx: Prisma.TransactionClient,
    acting: ActingFor,
    action: string,
    entityType: string,
    entityId: string | null,
    after: Prisma.InputJsonValue,
  ) {
    if (!acting.byCaregiver) return;
    await this.audit.record(
      { actorId: acting.actorId, subjectUserId: acting.subjectId, action, entityType, entityId, after: { ...(after as object), byCaregiver: true } },
      tx,
    );
  }

  private tellMember(acting: ActingFor, key: string) {
    return this.caregivers.notifyMember(acting, 'health_updated', `${acting.subjectId}:${key}:${Date.now()}`);
  }
}

function stripUndefined<T extends object>(o: T): Partial<T> {
  return Object.fromEntries(Object.entries(o).filter(([, v]) => v !== undefined)) as Partial<T>;
}

/** The care plan fields: custom habit names and test frequencies. */
function checkPlan(sent: Record<string, unknown>) {
  const custom = sent.customHabits as Record<string, unknown> | undefined;
  if (custom) {
    const entries = Object.entries(custom);
    if (entries.length > 10) throw new BadRequestException('Up to 10 habits of your own');
    for (const [k, v] of entries) {
      if (!CUSTOM_HABIT_KEY.test(k) || typeof v !== 'string' || !v.trim() || v.length > 80) {
        throw new BadRequestException('A habit of your own needs a short name');
      }
    }
  }
  const every = sent.testEveryMonths as Record<string, unknown> | undefined;
  if (every) {
    for (const [k, v] of Object.entries(every)) {
      if (!CODE.test(k) || !(TEST_EVERY_MONTHS as readonly number[]).includes(v as number)) {
        throw new BadRequestException('How often: as advised, or every 1, 3, 6 or 12 months');
      }
    }
  }
}

const intIn = (v: unknown, lo: number, hi: number) => typeof v === 'number' && Number.isInteger(v) && v >= lo && v <= hi;

/** Each kind keeps only its own fields. */
export function checkLogData(dto: CreateCareLogDto): Record<string, unknown> {
  const d = dto.data;
  switch (dto.kind) {
    case CareLogKind.SYMPTOMS: {
      const symptoms = d.symptoms;
      if (!dto.conditionCode) throw new BadRequestException('Which condition?');
      if (!Array.isArray(symptoms) || symptoms.length > 20 || !symptoms.every((s) => typeof s === 'string' && CODE.test(s))) {
        throw new BadRequestException('Pick the symptoms');
      }
      const fine = d.fine === true;
      if (!fine && symptoms.length === 0) throw new BadRequestException('Pick the symptoms');
      return { symptoms: fine ? [] : symptoms, fine };
    }
    case CareLogKind.KICKS:
      if (!intIn(d.count, 0, 200) || !intIn(d.minutes, 0, 240)) throw new BadRequestException('Count and minutes');
      return { count: d.count, minutes: d.minutes };
    case CareLogKind.RELIEVER: {
      const puffs = d.puffs ?? 1;
      if (!intIn(puffs, 1, 20)) throw new BadRequestException('How many puffs');
      return { puffs };
    }
    case CareLogKind.TD_DOSE:
      if (typeof d.date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(d.date) || Number.isNaN(Date.parse(d.date))) {
        throw new BadRequestException('The date of the dose');
      }
      return { date: d.date };
    default:
      throw new BadRequestException('Unknown entry');
  }
}
