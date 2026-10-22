import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { NotificationType, PrescriptionMedicine, PrescriptionStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { SaveMedicinesDto } from './dto/save-medicines.dto';
import { RoutineGenerationService } from './lib/routine-generation.service';
import { CloudinaryService } from './lib/cloudinary.service';
import { RuleEvaluationService } from '../health/rule-evaluation.service';
import { NotificationsService } from '../notifications/notifications.service';
import { messages } from '../notifications/notification-messages';

const SAFE_USER_SELECT = {
  id: true,
  name: true,
  phone: true,
  address: true,
} as const;

const PRESCRIPTION_INCLUDE = {
  medicines: { orderBy: { createdAt: 'asc' as const } },
  user: { select: SAFE_USER_SELECT },
  reviewedBy: { select: { id: true, name: true } },
};

@Injectable()
export class PrescriptionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly routineGeneration: RoutineGenerationService,
    private readonly ruleEvaluation: RuleEvaluationService,
    private readonly cloudinary: CloudinaryService,
    private readonly notifications: NotificationsService,
  ) {}

  // ---------------------------------------------------------------------
  // User-facing
  // ---------------------------------------------------------------------

  /**
   * Creates a prescription for the uploading user. If `clientId` was
   * already used for a previous (possibly retried) upload, returns the
   * existing prescription instead of creating a duplicate — this is what
   * makes the mobile app's offline-retry-on-reconnect flow safe.
   */
  async create(userId: string, imageBuffer: Buffer, originalFilename: string, clientId?: string) {
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
    return this.prisma.prescription.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      include: { medicines: { orderBy: { createdAt: 'asc' } } },
    });
  }

  async getMyPrescriptionDetail(userId: string, id: string) {
    const prescription = await this.prisma.prescription.findUnique({
      where: { id },
      include: PRESCRIPTION_INCLUDE,
    });
    if (!prescription || prescription.userId !== userId) {
      throw new NotFoundException('Prescription not found');
    }
    return prescription;
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
   * Adds/updates medicine line items while the prescription is still
   * PENDING. Marks each saved row `verified` by the acting admin — full
   * verification requires the structured schedule fields, checked at
   * completion time, not here, so the admin can save progress
   * incrementally.
   */
  async saveMedicines(adminId: string, prescriptionId: string, dto: SaveMedicinesDto) {
    const prescription = await this.prisma.prescription.findUnique({
      where: { id: prescriptionId },
    });
    if (!prescription) throw new NotFoundException('Prescription not found');
    if (prescription.status !== PrescriptionStatus.PENDING) {
      throw new ConflictException(
        `Cannot edit medicines on a prescription that is already ${prescription.status}`,
      );
    }

    const existingIds = new Set(
      (
        await this.prisma.prescriptionMedicine.findMany({
          where: { prescriptionId },
          select: { id: true },
        })
      ).map((m) => m.id),
    );

    const now = new Date();
    const ops = dto.medicines.map((entry) => {
      if (entry.id) {
        if (!existingIds.has(entry.id)) {
          throw new BadRequestException(`Medicine ${entry.id} does not belong to this prescription`);
        }
        return this.prisma.prescriptionMedicine.update({
          where: { id: entry.id },
          data: {
            medicineName: entry.medicineName,
            dosage: entry.dosage,
            frequency: entry.frequency,
            duration: entry.duration,
            instructions: entry.instructions ?? null,
            timesPerDay: entry.timesPerDay ?? null,
            scheduleTimes: entry.scheduleTimes ? JSON.stringify(entry.scheduleTimes) : null,
            durationDays: entry.durationDays ?? null,
            startDate: entry.startDate ?? null,
            verified: true,
            verifiedById: adminId,
            verifiedAt: now,
          },
        });
      }
      return this.prisma.prescriptionMedicine.create({
        data: {
          prescriptionId,
          medicineName: entry.medicineName,
          dosage: entry.dosage,
          frequency: entry.frequency,
          duration: entry.duration,
          instructions: entry.instructions ?? null,
          timesPerDay: entry.timesPerDay ?? null,
          scheduleTimes: entry.scheduleTimes ? JSON.stringify(entry.scheduleTimes) : null,
          durationDays: entry.durationDays ?? null,
          startDate: entry.startDate ?? null,
          verified: true,
          verifiedById: adminId,
          verifiedAt: now,
        },
      });
    });

    await this.prisma.$transaction(ops);
    return this.getDetailForAdmin(prescriptionId);
  }

  async removeMedicine(prescriptionId: string, medicineId: string) {
    const prescription = await this.prisma.prescription.findUnique({
      where: { id: prescriptionId },
    });
    if (!prescription) throw new NotFoundException('Prescription not found');
    if (prescription.status !== PrescriptionStatus.PENDING) {
      throw new ConflictException(
        `Cannot edit medicines on a prescription that is already ${prescription.status}`,
      );
    }
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
   * Completes a prescription: validates every medicine has the
   * structured schedule data routine generation needs, then
   * deterministically generates a MedicineRoutine (+ its doses) per
   * medicine, all in one transaction.
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

    const completedAt = new Date();
    const generatedRoutines = prescription.medicines.map((m) =>
      this.routineGeneration.generate(m, completedAt),
    );

    await this.prisma.$transaction(async (tx) => {
      // Compare-and-set on status: the PENDING check above happens outside the
      // transaction, so two admins (or a double click) could both pass it and
      // generate every routine/dose twice. Only one can win this update.
      const claimed = await tx.prescription.updateMany({
        where: { id: prescriptionId, status: PrescriptionStatus.PENDING },
        data: {
          status: PrescriptionStatus.COMPLETED,
          reviewedById: adminId,
          reviewedAt: completedAt,
        },
      });
      if (claimed.count === 0) {
        throw new ConflictException('Prescription is no longer pending');
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
    });

    // Health suggestion rules run against the now-verified medicines,
    // outside the transaction above: rule evaluation only ever creates
    // *additional* HealthReminder rows (see RuleEvaluationService's
    // dedup-by-rule policy), so it can't corrupt prescription/routine
    // state, and completion must succeed even if this loop hits an issue.
    for (const medicine of prescription.medicines) {
      await this.ruleEvaluation.evaluateForMedicine(prescription.userId, medicine);
    }

    // AI health suggestions are NOT generated here: an admin requests one per
    // routine from the routine panel (HealthSuggestionsService.requestForRoutine).

    await this.notifyOwner(prescription.userId, prescriptionId, 'COMPLETED');

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

    const claimed = await this.prisma.prescription.updateMany({
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

    await this.notifyOwner(prescription.userId, prescriptionId, 'REJECTED');

    return this.getDetailForAdmin(prescriptionId);
  }

  // ---------------------------------------------------------------------

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
      if (!m.durationDays) {
        problems.push(`"${m.medicineName}": durationDays is required`);
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
  private async notifyOwner(userId: string, prescriptionId: string, outcome: 'COMPLETED' | 'REJECTED') {
    try {
      const owner = await this.prisma.user.findUnique({
        where: { id: userId },
        select: { languagePreference: true },
      });
      if (!owner) return;
      const copy =
        outcome === 'COMPLETED'
          ? messages.prescriptionCompleted(owner.languagePreference)
          : messages.prescriptionRejected(owner.languagePreference);
      await this.notifications.notify([
        {
          userId,
          type: NotificationType.PRESCRIPTION_UPDATE,
          title: copy.title,
          body: copy.body,
          relatedEntityId: prescriptionId,
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
