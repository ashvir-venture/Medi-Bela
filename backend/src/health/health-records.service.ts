import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { HealthRecord, HealthRecordType, NotificationType, Prisma, RangeState } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import { ActingFor, CaregiverAccessService } from '../family/caregiver-access.service';
import { CreateHealthRecordDto } from './dto/create-health-record.dto';
import { UpdateHealthRecordDto } from './dto/update-health-record.dto';
import { rangeStateOf } from './lib/reading-range';

/** Plausible numbers per type (structured value only; `value` is display text). */
const NUMERIC_BOUNDS: Partial<Record<HealthRecordType, [number, number]>> = {
  BLOOD_SUGAR: [0.5, 40], // mmol/L
  WEIGHT: [1, 400], // kg
  TEMPERATURE: [90, 110], // °F
  INSULIN: [0.5, 200], // units
  SLEEP: [0, 24], // hours
  WATER: [0, 40], // glasses
  PEAK_FLOW: [50, 900], // L/min
  HEART_RATE: [20, 250],
};

const self = (userId: string): ActingFor => ({ actorId: userId, subjectId: userId, byCaregiver: false });

/** Who logged it goes out only as a flag (ids stay server-side). */
export function presentHealthRecord(r: HealthRecord) {
  const { enteredById, ...rest } = r;
  return { ...rest, byCaregiver: Boolean(enteredById && enteredById !== r.userId) };
}

@Injectable()
export class HealthRecordsService {
  private readonly logger = new Logger(HealthRecordsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly notifications: NotificationsService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  /**
   * Saves a reading for the user, or for a member their caregiver acts for.
   * Round 15: structured values are checked per type and the reading is
   * judged against the saved limits (rangeState). Out of range + "Tell my
   * family" on = one neutral push to the family's caregiver.
   */
  async create(who: string | ActingFor, dto: CreateHealthRecordDto) {
    const acting = typeof who === 'string' ? self(who) : who;
    const userId = acting.subjectId;
    this.checkStructured(dto);
    // Idempotent for offline retries: the same (user, clientId) returns the
    // record created the first time instead of a duplicate.
    if (dto.clientId) {
      const existing = await this.prisma.healthRecord.findUnique({
        where: { userId_clientId: { userId, clientId: dto.clientId } },
      });
      if (existing) return presentHealthRecord(existing);
    }
    let created: HealthRecord;
    try {
      created = await this.createRow(acting, dto);
    } catch (err) {
      // Two concurrent retries: the loser reads the winner's row.
      if (dto.clientId && err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        const existing = await this.prisma.healthRecord.findUnique({
          where: { userId_clientId: { userId, clientId: dto.clientId } },
        });
        if (existing) return presentHealthRecord(existing);
      }
      throw err;
    }
    if (acting.byCaregiver) {
      await this.audit.record({
        actorId: acting.actorId,
        subjectUserId: userId,
        action: 'health_record.create',
        entityType: 'health_record',
        entityId: created.id,
        after: { type: created.type, byCaregiver: true },
      });
      await this.caregivers.notifyMember(acting, 'health_updated', `record:${created.id}`);
    }
    if (created.rangeState === RangeState.ABOVE || created.rangeState === RangeState.BELOW) {
      await this.alertCaregiver(acting, created.id);
    }
    return presentHealthRecord(created);
  }

  private async createRow(acting: ActingFor, dto: CreateHealthRecordDto) {
    const userId = acting.subjectId;
    const limits = await this.prisma.healthLimits.findUnique({ where: { userId } });
    const rangeState = rangeStateOf(
      { type: dto.type, numericValue: dto.numericValue, systolic: dto.systolic, diastolic: dto.diastolic, sugarContext: dto.sugarContext },
      limits,
    );
    return this.prisma.healthRecord.create({
      data: {
        userId,
        clientId: dto.clientId,
        type: dto.type,
        value: dto.value,
        unit: dto.unit,
        notes: dto.notes,
        recordedAt: dto.recordedAt ? new Date(dto.recordedAt) : new Date(),
        numericValue: dto.numericValue ?? null,
        systolic: dto.systolic ?? null,
        diastolic: dto.diastolic ?? null,
        pulse: dto.pulse ?? null,
        bpArm: dto.bpArm ?? null,
        measurements: dto.measurements ?? null,
        sugarContext: dto.sugarContext ?? null,
        injectionSite: dto.injectionSite ?? null,
        injectionGiver: dto.injectionGiver ?? null,
        doseId: dto.doseId ?? null,
        rangeState,
        enteredById: acting.byCaregiver ? acting.actorId : null,
      },
    });
  }

  /** Structured fields must fit the type they are sent with. */
  private checkStructured(dto: CreateHealthRecordDto) {
    const bpFields = dto.systolic != null || dto.diastolic != null || dto.pulse != null || dto.bpArm != null || dto.measurements != null;
    if (bpFields && dto.type !== HealthRecordType.BLOOD_PRESSURE) {
      throw new BadRequestException('Blood pressure fields only go with a blood pressure reading');
    }
    if (dto.type === HealthRecordType.BLOOD_PRESSURE && (dto.systolic == null) !== (dto.diastolic == null)) {
      throw new BadRequestException('Give both blood pressure numbers');
    }
    if (dto.sugarContext != null && dto.type !== HealthRecordType.BLOOD_SUGAR) {
      throw new BadRequestException('When-checked only goes with a sugar reading');
    }
    const insulinFields = dto.injectionSite != null || dto.injectionGiver != null || dto.doseId != null;
    if (insulinFields && dto.type !== HealthRecordType.INSULIN) {
      throw new BadRequestException('Injection fields only go with an insulin entry');
    }
    if (dto.numericValue != null) {
      const bounds = NUMERIC_BOUNDS[dto.type];
      if (!bounds) throw new BadRequestException('This kind of reading takes no number');
      if (dto.numericValue < bounds[0] || dto.numericValue > bounds[1]) {
        throw new BadRequestException('The number is outside the possible range');
      }
    }
  }

  /** Neutral push to the caregiver (never the value). Never fails the save. */
  private async alertCaregiver(acting: ActingFor, recordId: string) {
    try {
      const limits = await this.prisma.healthLimits.findUnique({
        where: { userId: acting.subjectId },
        select: { notifyFamily: true },
      });
      if (!limits?.notifyFamily) return;
      const caregiver = await this.caregivers.caregiverOf(acting.subjectId);
      // The caregiver who logged it for the member already knows.
      if (!caregiver || caregiver.id === acting.actorId) return;
      const copy = messages.readingOutOfRangeCaregiver(caregiver.languagePreference, caregiver.memberName);
      await this.notifications.notify([
        {
          userId: caregiver.id,
          type: NotificationType.SYSTEM,
          title: copy.title,
          body: copy.body,
          relatedEntityId: `reading:${recordId}`,
          data: { kind: 'reading_alert', memberUserId: acting.subjectId },
        },
      ]);
    } catch (err) {
      this.logger.warn(`Reading alert failed: ${(err as Error).message}`);
    }
  }

  async list(userId: string, type?: HealthRecordType) {
    const rows = await this.prisma.healthRecord.findMany({
      where: { userId, ...(type ? { type } : {}) },
      orderBy: { recordedAt: 'desc' },
    });
    return rows.map(presentHealthRecord);
  }

  async getDetail(userId: string, id: string) {
    return presentHealthRecord(await this.own(userId, id));
  }

  private async own(userId: string, id: string) {
    const record = await this.prisma.healthRecord.findUnique({ where: { id } });
    if (!record || record.userId !== userId) {
      throw new NotFoundException('Health record not found');
    }
    return record;
  }

  /**
   * Corrects a mistaken entry (e.g. a typo'd value). Deliberately narrow:
   * only `value`/`unit`/`notes` are editable — `type` and `recordedAt`
   * are not, since a health record is a point-in-time log entry, not a
   * mutable "current status" row; changing what was measured or when
   * would misrepresent history rather than correct it.
   */
  async update(userId: string, id: string, dto: UpdateHealthRecordDto) {
    await this.own(userId, id); // ownership check
    const saved = await this.prisma.healthRecord.update({
      where: { id },
      data: { value: dto.value, unit: dto.unit, notes: dto.notes },
    });
    return presentHealthRecord(saved);
  }
}
