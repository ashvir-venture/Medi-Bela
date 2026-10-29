import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  NotificationType,
  PrescriptionMedicine,
  PrescriptionStatus,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { SaveMedicinesDto } from './dto/save-medicines.dto';
import { SavePrescriptionDetailsDto } from './dto/save-details.dto';
import { QueueStatus } from './dto/queue-query.dto';
import { RoutineGenerationService } from './lib/routine-generation.service';
import { CloudinaryService } from './lib/cloudinary.service';
import { RuleEvaluationService } from '../health/rule-evaluation.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';
import { AuditService } from '../audit/audit.service';
import { CatalogService } from '../catalog/catalog.service';
import { ActingFor, CaregiverAccessService } from '../family/caregiver-access.service';
import { ConfirmLineDto, ConfirmPrescriptionDto } from './dto/confirm-prescription.dto';
import { startOfAppDay } from '../common/utils/time.util';
import {
  ADMIN_PAGE_SIZE,
  CURSOR_ORDER,
  cursorWhere,
  toCursorPage,
} from '../common/utils/cursor-pagination';

const SAFE_USER_SELECT = {
  id: true,
  name: true,
  phone: true,
  address: true,
} as const;

const PRESCRIPTION_INCLUDE = {
  medicines: {
    orderBy: { createdAt: 'asc' as const },
    include: {
      medicine: { include: { form: true } },
      mealTiming: true,
    },
  },
  user: { select: SAFE_USER_SELECT },
  reviewedBy: { select: { id: true, name: true } },
  doctor: { include: { specialty: true } },
  tests: { include: { test: true } },
  // A re-upload shows the pharmacist why the earlier one was rejected.
  previous: { select: { id: true, status: true, rejectionReason: true, createdAt: true } },
};

type ReviewOutcome = 'READY_TO_CONFIRM' | 'ACTIVE' | 'REJECTED';

/** Adds "done by caregiver" flags; ids of who acted stay server-side. */
function withActorFlags<T extends { userId: string; uploadedById?: string | null; confirmedById?: string | null }>(
  p: T,
) {
  const { uploadedById, confirmedById, ...rest } = p;
  return {
    ...rest,
    uploadedByCaregiver: Boolean(uploadedById && uploadedById !== p.userId),
    confirmedByCaregiver: Boolean(confirmedById && confirmedById !== p.userId),
  };
}

/** YYYY-MM-DD (validated by the DTO) -> Date for a @db.Date column; null clears. */
function toDateColumn(value: string | null | undefined): Date | null | undefined {
  if (value === undefined) return undefined;
  return value === null ? null : new Date(`${value}T00:00:00.000Z`);
}

@Injectable()
export class PrescriptionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly routineGeneration: RoutineGenerationService,
    private readonly ruleEvaluation: RuleEvaluationService,
    private readonly cloudinary: CloudinaryService,
    private readonly notifications: NotificationsService,
    private readonly audit: AuditService,
    private readonly catalog: CatalogService,
    private readonly caregivers: CaregiverAccessService,
  ) {}

  // ---------------------------------------------------------------------
  // User-facing
  // ---------------------------------------------------------------------

  /**
   * Creates a prescription for the uploading user. If `clientId` was
   * already used for a previous (possibly retried) upload, returns the
   * existing prescription instead of creating a duplicate — this is what
   * makes the mobile app's offline-retry-on-reconnect flow safe.
   *
   * `previousPrescriptionId` links a re-upload to the user's own REJECTED
   * prescription so the pharmacist sees the earlier feedback.
   * `uploadedById` differs from `userId` when a caregiver uploads for them.
   */
  async create(
    userId: string,
    imageBuffer: Buffer,
    originalFilename: string,
    clientId?: string,
    previousPrescriptionId?: string,
    uploadedById: string = userId,
  ) {
    if (clientId) {
      const existing = await this.prisma.prescription.findUnique({
        where: { clientUploadId: clientId },
      });
      if (existing) {
        if (existing.userId !== userId) {
          // Extremely unlikely (uuid collision across users) but never
          // hand back another user's record.
          throw new ConflictException('clientId already in use');
        }
        return existing;
      }
    }

    if (previousPrescriptionId) {
      const previous = await this.prisma.prescription.findUnique({
        where: { id: previousPrescriptionId },
        select: { userId: true, status: true },
      });
      // Same answer for "not yours" and "missing": nothing to probe.
      if (!previous || previous.userId !== userId) {
        throw new BadRequestException('previousPrescriptionId does not match one of your prescriptions');
      }
      if (previous.status !== PrescriptionStatus.REJECTED) {
        throw new BadRequestException('Only a rejected prescription can be re-uploaded');
      }
    }

    // One file per request: uploaded to Cloudinary before the DB write
    // so a failed upload never creates a prescription row pointing at
    // nothing.
    const imageUrl = await this.cloudinary.uploadPrescriptionImage(imageBuffer, originalFilename);

    try {
      return await this.prisma.prescription.create({
        data: {
          userId,
          imageUrl,
          clientUploadId: clientId ?? null,
          previousPrescriptionId: previousPrescriptionId ?? null,
          uploadedById,
        },
      });
    } catch (e) {
      // Race: two near-simultaneous retries with the same clientId. The
      // unique constraint on clientUploadId caught it — fetch and return
      // the winner instead of erroring the client.
      if (clientId && this.isUniqueConstraintError(e)) {
        const existing = await this.prisma.prescription.findUnique({
          where: { clientUploadId: clientId },
        });
        if (existing) return existing;
      }
      throw e;
    }
  }

  async getMyHistory(userId: string) {
    const rows = await this.prisma.prescription.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: { medicines: { orderBy: { createdAt: 'asc' } } },
    });
    return rows.map(withActorFlags);
  }

  async getMyPrescriptionDetail(userId: string, id: string) {
    const prescription = await this.prisma.prescription.findUnique({
      where: { id },
      include: PRESCRIPTION_INCLUDE,
    });
    if (!prescription || prescription.userId !== userId) {
      throw new NotFoundException('Prescription not found');
    }
    return withActorFlags(prescription);
  }

  /**
   * The patient's Confirm or Edit step (or their caregiver's, acting for
   * them). Allowed edits per line: dose times (same count), start date,
   * meal timing, or removing the line; everything else stays as the
   * pharmacist set it. Then routines and doses are created ([activate]).
   */
  async confirm(acting: ActingFor, prescriptionId: string, dto: ConfirmPrescriptionDto) {
    const prescription = await this.prisma.prescription.findUnique({
      where: { id: prescriptionId },
      include: { medicines: true },
    });
    if (!prescription || prescription.userId !== acting.subjectId) {
      throw new NotFoundException('Prescription not found');
    }
    if (prescription.status !== PrescriptionStatus.AWAITING_CONFIRMATION) {
      throw new ConflictException(`Prescription is ${prescription.status}, not awaiting confirmation`);
    }

    const lines = prescription.medicines.filter((m) => m.revision === prescription.currentRevision);
    const byId = new Map(lines.map((m) => [m.id, m]));
    const edits = dto.lines ?? [];
    const seen = new Set<string>();
    const today = startOfAppDay(new Date());
    for (const edit of edits) {
      const line = byId.get(edit.id);
      if (!line) throw new BadRequestException(`Medicine ${edit.id} is not on this prescription`);
      if (seen.has(edit.id)) throw new BadRequestException(`Medicine ${edit.id} is listed twice`);
      seen.add(edit.id);
      if (edit.scheduleTimes && edit.scheduleTimes.length !== line.timesPerDay) {
        throw new BadRequestException(
          `"${line.medicineName}": choose exactly ${line.timesPerDay} dose time(s)`,
        );
      }
      if (edit.startDate && startOfAppDay(new Date(`${edit.startDate}T00:00:00.000Z`)) < today) {
        throw new BadRequestException(`"${line.medicineName}": the start date can't be in the past`);
      }
    }
    if (edits.filter((e) => e.remove).length >= lines.length) {
      throw new BadRequestException('Keep at least one medicine to confirm this prescription');
    }
    const mealIds = [...new Set(edits.map((e) => e.mealTimingId).filter((v): v is number => typeof v === 'number'))];
    if (mealIds.length) {
      const found = await this.prisma.mealTiming.count({ where: { id: { in: mealIds } } });
      if (found !== mealIds.length) throw new BadRequestException('Unknown meal timing');
    }

    const result = await this.activate(acting.actorId, prescriptionId, edits);
    await this.caregivers.notifyMember(acting, 'prescription_confirmed', prescriptionId);
    return withActorFlags(result);
  }

  // ---------------------------------------------------------------------
  // Admin/pharmacist-facing
  // ---------------------------------------------------------------------

  async listPending() {
    return this.prisma.prescription.findMany({
      where: { status: PrescriptionStatus.PENDING },
      orderBy: { createdAt: 'asc' },
      include: { user: { select: SAFE_USER_SELECT } },
    });
  }

  /** Paginated queue (20 per page, newest first) filtered by status. */
  async listQueue(status: QueueStatus = PrescriptionStatus.PENDING, cursor?: string) {
    const rows = await this.prisma.prescription.findMany({
      where: {
        ...(status === 'ALL' ? {} : { status }),
        ...cursorWhere(cursor),
      },
      orderBy: CURSOR_ORDER,
      take: ADMIN_PAGE_SIZE + 1,
      select: {
        id: true,
        status: true,
        imageUrl: true,
        createdAt: true,
        reviewedAt: true,
        previousPrescriptionId: true,
        user: { select: SAFE_USER_SELECT },
        reviewedBy: { select: { id: true, name: true } },
      },
    });
    return toCursorPage(rows, ADMIN_PAGE_SIZE);
  }

  async getDetailForAdmin(id: string) {
    const prescription = await this.prisma.prescription.findUnique({
      where: { id },
      include: PRESCRIPTION_INCLUDE,
    });
    if (!prescription) {
      throw new NotFoundException('Prescription not found');
    }
    return prescription;
  }

  /**
   * Saves the prescription-level fields while PENDING: doctor block, visit
   * date, diagnosis, next visit and tests. A typed doctor (not picked from
   * the list) creates a Doctor row; Not applicable clears the doctor and
   * creates nothing.
   */
  async saveDetails(actorId: string, prescriptionId: string, dto: SavePrescriptionDetailsDto) {
    await this.assertPending(prescriptionId);
    const doctorChoices = [dto.doctorId, dto.doctor, dto.doctorNotApplicable || undefined].filter(
      (v) => v !== undefined,
    );
    if (doctorChoices.length > 1) {
      throw new BadRequestException('Choose one of doctorId, doctor or doctorNotApplicable');
    }
    if (dto.doctorId) {
      const exists = await this.prisma.doctor.findUnique({ where: { id: dto.doctorId }, select: { id: true } });
      if (!exists) throw new BadRequestException('Doctor not found');
    }
    const testIds = dto.testIds ? [...new Set(dto.testIds)] : undefined;
    if (testIds?.length) {
      const found = await this.prisma.diagnosticTest.count({ where: { id: { in: testIds } } });
      if (found !== testIds.length) throw new BadRequestException('Unknown test in testIds');
    }

    await this.prisma.$transaction(async (tx) => {
      let doctorId: string | null | undefined;
      if (dto.doctorNotApplicable) doctorId = null;
      else if (dto.doctorId) doctorId = dto.doctorId;
      else if (dto.doctor) doctorId = (await this.catalog.createDoctor(actorId, dto.doctor, tx)).id;

      await tx.prescription.update({
        where: { id: prescriptionId },
        data: {
          doctorId,
          visitDate: toDateColumn(dto.visitDate),
          diagnosis: dto.diagnosis === undefined ? undefined : dto.diagnosis || null,
          nextVisitDate: toDateColumn(dto.nextVisitDate),
        },
      });

      if (testIds) {
        await tx.prescriptionTest.deleteMany({ where: { prescriptionId } });
        await tx.prescriptionTest.createMany({
          data: testIds.map((testId) => ({ prescriptionId, testId })),
        });
      }
    });

    return this.getDetailForAdmin(prescriptionId);
  }

  /**
   * Adds/updates medicine line items while the prescription is still
   * PENDING. Marks each saved row `verified` by the acting pharmacist —
   * full verification requires the structured schedule fields, checked at
   * completion time, not here, so the pharmacist can save progress
   * incrementally. A line without `medicineId` is linked to the catalog by
   * brand name (a stub Medicine is created when it is new), so every line
   * ends up doctor -> prescription -> medicine.
   */
  async saveMedicines(adminId: string, prescriptionId: string, dto: SaveMedicinesDto) {
    await this.assertPending(prescriptionId);

    const existingIds = new Set(
      (
        await this.prisma.prescriptionMedicine.findMany({
          where: { prescriptionId },
          select: { id: true },
        })
      ).map((m) => m.id),
    );
    for (const entry of dto.medicines) {
      if (entry.id && !existingIds.has(entry.id)) {
        throw new BadRequestException(`Medicine ${entry.id} does not belong to this prescription`);
      }
    }

    const now = new Date();
    await this.prisma.$transaction(async (tx) => {
      for (const entry of dto.medicines) {
        const medicineId =
          entry.medicineId ?? (await this.catalog.findOrCreateMedicineStub(adminId, entry.medicineName, tx));
        const data = {
          medicineName: entry.medicineName,
          dosage: entry.dosage,
          frequency: entry.frequency,
          duration: entry.duration,
          instructions: entry.instructions ?? null,
          timesPerDay: entry.timesPerDay ?? null,
          scheduleTimes: entry.scheduleTimes ? JSON.stringify(entry.scheduleTimes) : null,
          durationDays: entry.durationDays ?? null,
          startDate: entry.startDate ?? null,
          medicineId,
          strength: entry.strength ?? null,
          doseAmount: entry.doseAmount ?? null,
          mealTimingId: entry.mealTimingId ?? null,
          continuous: entry.continuous ?? false,
          verified: true,
          verifiedById: adminId,
          verifiedAt: now,
        };
        if (entry.id) {
          await tx.prescriptionMedicine.update({ where: { id: entry.id }, data });
        } else {
          await tx.prescriptionMedicine.create({ data: { prescriptionId, ...data } });
        }
      }
    });

    return this.getDetailForAdmin(prescriptionId);
  }

  async removeMedicine(prescriptionId: string, medicineId: string) {
    await this.assertPending(prescriptionId);
    const medicine = await this.prisma.prescriptionMedicine.findUnique({
      where: { id: medicineId },
    });
    if (!medicine || medicine.prescriptionId !== prescriptionId) {
      throw new NotFoundException('Medicine entry not found');
    }
    await this.prisma.prescriptionMedicine.delete({ where: { id: medicineId } });
    return this.getDetailForAdmin(prescriptionId);
  }

  /**
   * The pharmacist finishes a prescription: validates that every medicine
   * has the structured schedule data routine generation needs, then sends
   * it to the user as AWAITING_CONFIRMATION. No routine or dose exists yet;
   * they are created when the user confirms ([activate], Round 6 screen).
   */
  async complete(adminId: string, prescriptionId: string) {
    const prescription = await this.prisma.prescription.findUnique({
      where: { id: prescriptionId },
      include: { medicines: true },
    });
    if (!prescription) throw new NotFoundException('Prescription not found');
    if (prescription.status !== PrescriptionStatus.PENDING) {
      throw new ConflictException(`Prescription is already ${prescription.status}`);
    }
    if (prescription.medicines.length === 0) {
      throw new BadRequestException('Cannot complete a prescription with no medicines entered');
    }

    this.assertMedicinesReadyForCompletion(prescription.medicines);

    await this.prisma.$transaction(async (tx) => {
      // Compare-and-set on status: two pharmacists (or a double click) can
      // both pass the PENDING check above; only one wins this update.
      const claimed = await tx.prescription.updateMany({
        where: { id: prescriptionId, status: PrescriptionStatus.PENDING },
        data: {
          status: PrescriptionStatus.AWAITING_CONFIRMATION,
          reviewedById: adminId,
          reviewedAt: new Date(),
        },
      });
      if (claimed.count === 0) {
        throw new ConflictException('Prescription is no longer pending');
      }
      await this.audit.record(
        {
          actorId: adminId,
          subjectUserId: prescription.userId,
          action: 'prescription.prepare',
          entityType: 'prescription',
          entityId: prescriptionId,
          before: { status: PrescriptionStatus.PENDING },
          after: {
            status: PrescriptionStatus.AWAITING_CONFIRMATION,
            medicineLines: prescription.medicines.length,
          },
        },
        tx,
      );
    });

    await this.notifyOwner(prescription.userId, prescriptionId, 'READY_TO_CONFIRM');

    return this.getDetailForAdmin(prescriptionId);
  }

  /**
   * AWAITING_CONFIRMATION -> ACTIVE: deterministically generates a
   * MedicineRoutine (+ its first doses) per kept medicine line, in one
   * transaction, then runs the health rules. Reached through [confirm],
   * which validates the patient's edits first. Edited lines produce
   * routines marked as edited by the actor; the pharmacist's line itself
   * is kept unchanged. Removed lines are deleted.
   */
  async activate(actorId: string, prescriptionId: string, edits: ConfirmLineDto[] = []) {
    const prescription = await this.prisma.prescription.findUnique({
      where: { id: prescriptionId },
      include: { medicines: true },
    });
    if (!prescription) throw new NotFoundException('Prescription not found');
    if (prescription.status !== PrescriptionStatus.AWAITING_CONFIRMATION) {
      throw new ConflictException(`Prescription is ${prescription.status}, not awaiting confirmation`);
    }
    const editById = new Map(edits.map((e) => [e.id, e]));
    const current = prescription.medicines.filter((m) => m.revision === prescription.currentRevision);
    const removed = current.filter((m) => editById.get(m.id)?.remove);
    const editedIds = new Set<string>();
    const lines = current
      .filter((m) => !editById.get(m.id)?.remove)
      .map((m) => {
        const edit = editById.get(m.id);
        if (!edit) return m;
        const changed = { ...m };
        if (edit.scheduleTimes) changed.scheduleTimes = JSON.stringify(edit.scheduleTimes);
        if (edit.startDate) changed.startDate = new Date(`${edit.startDate}T00:00:00.000Z`);
        if (edit.mealTimingId !== undefined) changed.mealTimingId = edit.mealTimingId;
        if (
          changed.scheduleTimes !== m.scheduleTimes ||
          changed.startDate?.getTime() !== m.startDate?.getTime() ||
          changed.mealTimingId !== m.mealTimingId
        ) {
          editedIds.add(m.id);
        }
        return changed;
      });
    if (lines.length === 0) {
      throw new BadRequestException('Keep at least one medicine to confirm this prescription');
    }
    this.assertMedicinesReadyForCompletion(lines);

    const activatedAt = new Date();
    const generatedRoutines = lines.map((m) => this.routineGeneration.generate(m, activatedAt));

    await this.prisma.$transaction(async (tx) => {
      const claimed = await tx.prescription.updateMany({
        where: { id: prescriptionId, status: PrescriptionStatus.AWAITING_CONFIRMATION },
        data: { status: PrescriptionStatus.ACTIVE, confirmedById: actorId, confirmedAt: activatedAt },
      });
      if (claimed.count === 0) {
        throw new ConflictException('Prescription is no longer awaiting confirmation');
      }
      if (removed.length) {
        await tx.prescriptionMedicine.deleteMany({ where: { id: { in: removed.map((m) => m.id) } } });
      }

      for (const routine of generatedRoutines) {
        const createdRoutine = await tx.medicineRoutine.create({
          data: {
            userId: prescription.userId,
            prescriptionMedicineId: routine.prescriptionMedicineId,
            medicineName: routine.medicineName,
            dosage: routine.dosage,
            frequency: routine.frequency,
            startDate: routine.startDate,
            endDate: routine.endDate,
            active: true,
            strength: routine.strength,
            doseAmount: routine.doseAmount,
            mealTimingId: routine.mealTimingId,
            scheduleTimes: routine.scheduleTimes,
            generatedUntil: routine.generatedUntil,
            // "Edited by you" / "edited by caregiver" when the patient side changed it.
            ...(editedIds.has(routine.prescriptionMedicineId)
              ? { lastEditedById: actorId, lastEditedAt: activatedAt }
              : {}),
          },
        });

        await tx.medicineDose.createMany({
          data: routine.doses.map((dose) => ({
            routineId: createdRoutine.id,
            userId: prescription.userId,
            scheduledAt: dose.scheduledAt,
          })),
        });
      }

      await this.audit.record(
        {
          actorId,
          subjectUserId: prescription.userId,
          action: 'prescription.confirm',
          entityType: 'prescription',
          entityId: prescriptionId,
          before: {
            status: PrescriptionStatus.AWAITING_CONFIRMATION,
            removedLines: removed.map((m) => ({ id: m.id, medicineName: m.medicineName })),
          },
          after: {
            status: PrescriptionStatus.ACTIVE,
            routines: generatedRoutines.length,
            editedLines: [...editedIds],
          },
        },
        tx,
      );
    });

    // Health suggestion rules run against the now-active medicines,
    // outside the transaction above: rule evaluation only ever creates
    // *additional* HealthReminder rows (see RuleEvaluationService's
    // dedup-by-rule policy), so it can't corrupt prescription/routine
    // state, and activation must succeed even if this loop hits an issue.
    for (const medicine of lines) {
      await this.ruleEvaluation.evaluateForMedicine(prescription.userId, medicine);
    }

    // AI health suggestions are NOT generated here: an admin requests one per
    // routine from the routine panel (HealthSuggestionsService.requestForRoutine).

    await this.notifyOwner(prescription.userId, prescriptionId, 'ACTIVE');

    return this.getDetailForAdmin(prescriptionId);
  }

  async reject(adminId: string, prescriptionId: string, rejectionReason: string) {
    const prescription = await this.prisma.prescription.findUnique({
      where: { id: prescriptionId },
    });
    if (!prescription) throw new NotFoundException('Prescription not found');
    if (prescription.status !== PrescriptionStatus.PENDING) {
      throw new ConflictException(`Prescription is already ${prescription.status}`);
    }

    await this.prisma.$transaction(async (tx) => {
      const claimed = await tx.prescription.updateMany({
        where: { id: prescriptionId, status: PrescriptionStatus.PENDING },
        data: {
          status: PrescriptionStatus.REJECTED,
          reviewedById: adminId,
          reviewedAt: new Date(),
          rejectionReason,
        },
      });
      if (claimed.count === 0) {
        throw new ConflictException('Prescription is no longer pending');
      }
      // The feedback text stays on the prescription; the audit row only
      // records the transition.
      await this.audit.record(
        {
          actorId: adminId,
          subjectUserId: prescription.userId,
          action: 'prescription.reject',
          entityType: 'prescription',
          entityId: prescriptionId,
          before: { status: PrescriptionStatus.PENDING },
          after: { status: PrescriptionStatus.REJECTED },
        },
        tx,
      );
    });

    await this.notifyOwner(prescription.userId, prescriptionId, 'REJECTED');

    return this.getDetailForAdmin(prescriptionId);
  }

  // ---------------------------------------------------------------------

  private async assertPending(prescriptionId: string) {
    const prescription = await this.prisma.prescription.findUnique({
      where: { id: prescriptionId },
      select: { status: true },
    });
    if (!prescription) throw new NotFoundException('Prescription not found');
    if (prescription.status !== PrescriptionStatus.PENDING) {
      throw new ConflictException(
        `Cannot edit a prescription that is already ${prescription.status}`,
      );
    }
  }

  /**
   * Enforces that routine generation never has to invent anything.
   * Deliberately conservative: any medicine missing structured schedule
   * data blocks completion rather than falling back to a guessed
   * default, per the "no invented medical defaults" requirement.
   */
  private assertMedicinesReadyForCompletion(medicines: PrescriptionMedicine[]) {
    const problems: string[] = [];
    for (const m of medicines) {
      if (!m.timesPerDay) {
        problems.push(`"${m.medicineName}": timesPerDay is required`);
        continue;
      }
      if (!m.durationDays && !m.continuous) {
        problems.push(`"${m.medicineName}": durationDays is required (or mark it continuous)`);
        continue;
      }
      let times: unknown = [];
      try {
        times = m.scheduleTimes ? JSON.parse(m.scheduleTimes) : [];
      } catch {
        times = [];
      }
      if (!Array.isArray(times) || times.length !== m.timesPerDay) {
        problems.push(
          `"${m.medicineName}": scheduleTimes must list exactly ${m.timesPerDay} time(s)`,
        );
      }
    }
    if (problems.length > 0) {
      throw new BadRequestException({
        message: 'Cannot complete prescription: medicine schedule data is incomplete',
        details: problems,
      });
    }
  }

  /**
   * Push + inbox entry for the prescription's owner. The text deliberately
   * omits the rejection reason and any medicine detail (lock-screen / FCM
   * transit); the app shows those after the user opens it. Idempotent per
   * (user, type, prescription) and never allowed to fail the review itself.
   */
  private async notifyOwner(userId: string, prescriptionId: string, outcome: ReviewOutcome) {
    try {
      const owner = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { languagePreference: true },
      });
      if (!owner) return;
      const copy =
        outcome === 'ACTIVE'
          ? messages.prescriptionCompleted(owner.languagePreference)
          : outcome === 'READY_TO_CONFIRM'
            ? messages.prescriptionReadyToConfirm(owner.languagePreference)
            : messages.prescriptionRejected(owner.languagePreference);
      await this.notifications.notify([
        {
          userId,
          type: NotificationType.PRESCRIPTION_UPDATE,
          title: copy.title,
          body: copy.body,
          // ACTIVE follows READY_TO_CONFIRM for the same prescription, so it
          // needs its own key to get past the per-entity dedup.
          relatedEntityId: outcome === 'ACTIVE' ? `active:${prescriptionId}` : prescriptionId,
          data: { prescriptionId },
        },
      ]);
    } catch {
      // A notification problem must never turn a successful review into an error.
    }
  }

  private isUniqueConstraintError(e: unknown): boolean {
    return typeof e === 'object' && e !== null && (e as { code?: string }).code === 'P2002';
  }
}
