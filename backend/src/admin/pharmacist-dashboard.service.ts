import { Injectable } from '@nestjs/common';
import { PrescriptionStatus, SuggestionStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { appDayBounds } from '../common/utils/time.util';
import { DOCTOR_INCOMPLETE_WHERE, MEDICINE_INCOMPLETE_WHERE } from '../catalog/lib/catalog-completeness';

const OLDEST_LIMIT = 5;

/**
 * The pharmacist's overview: what is waiting for them and what they
 * finished today. Counts plus patient names on the waiting rows (which the
 * pharmacist opens anyway); no medicine or health detail.
 */
@Injectable()
export class PharmacistDashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async getDashboard(pharmacistId: string, now: Date = new Date()) {
    const { start: todayStart, end: todayEnd } = appDayBounds(now);
    const reviewedToday = { gte: todayStart, lt: todayEnd };

    const [
      pending,
      reuploads,
      awaitingConfirmation,
      preparedByMeToday,
      rejectedByMeToday,
      incompleteDoctors,
      incompleteMedicines,
      draftSuggestions,
      oldestPending,
    ] = await Promise.all([
      this.prisma.prescription.count({ where: { status: PrescriptionStatus.PENDING } }),
      this.prisma.prescription.count({
        where: { status: PrescriptionStatus.PENDING, previousPrescriptionId: { not: null } },
      }),
      this.prisma.prescription.count({ where: { status: PrescriptionStatus.AWAITING_CONFIRMATION } }),
      this.prisma.prescription.count({
        where: {
          reviewedById: pharmacistId,
          reviewedAt: reviewedToday,
          status: { not: PrescriptionStatus.REJECTED },
        },
      }),
      this.prisma.prescription.count({
        where: { reviewedById: pharmacistId, reviewedAt: reviewedToday, status: PrescriptionStatus.REJECTED },
      }),
      this.prisma.doctor.count({ where: DOCTOR_INCOMPLETE_WHERE }),
      this.prisma.medicine.count({ where: MEDICINE_INCOMPLETE_WHERE }),
      this.prisma.healthSuggestion.count({ where: { status: SuggestionStatus.DRAFT } }),
      this.prisma.prescription.findMany({
        where: { status: PrescriptionStatus.PENDING },
        orderBy: { createdAt: 'asc' },
        take: OLDEST_LIMIT,
        select: {
          id: true,
          createdAt: true,
          previousPrescriptionId: true,
          user: { select: { id: true, name: true } },
        },
      }),
    ]);

    return {
      generatedAt: now.toISOString(),
      queue: { pending, reuploads, awaitingConfirmation },
      today: { prepared: preparedByMeToday, rejected: rejectedByMeToday },
      catalog: { incompleteDoctors, incompleteMedicines },
      aiSuggestions: { drafts: draftSuggestions },
      oldestPending,
    };
  }
}
