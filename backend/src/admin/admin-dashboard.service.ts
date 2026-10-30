import { Injectable } from '@nestjs/common';
import { AccountStatus, DoseStatus, NoticeStatus, PrescriptionStatus, Role, SuggestionStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { missedCutoff } from '../medicine-schedule/lib/dose-status.util';
import { addAppDays, appDayBounds, appUtcOffsetMinutes } from '../common/utils/time.util';

const TREND_DAYS = 14;
const ADHERENCE_DAYS = 7;
const RECENT_LIMIT = 10;

/**
 * Read-only aggregates for the admin dashboard. All the counting lives here
 * so the Next.js app only renders; it never recomputes anything.
 * Deliberately numbers only (plus names on the recent-prescription rows the
 * admin can already open): no medicine or health detail leaves this endpoint.
 */
@Injectable()
export class AdminDashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async getDashboard(now: Date = new Date()) {
    const { start: todayStart, end: todayEnd } = appDayBounds(now);
    const trendStart = addAppDays(todayStart, -(TREND_DAYS - 1));
    const adherenceStart = addAppDays(todayStart, -(ADHERENCE_DAYS - 1));
    const cutoff = missedCutoff(now);

    const [
      users,
      families,
      pending,
      completed,
      rejected,
      recent,
      prescriptionDates,
      userDates,
      taken,
      missed,
      overduePending,
      liveNotices,
      activeRules,
      draftSuggestions,
      noticesAwaitingApproval,
    ] = await Promise.all([
      this.prisma.user.count({ where: { role: Role.USER, accountStatus: { not: AccountStatus.DELETED } } }),
      this.prisma.family.count(),
      this.prisma.prescription.count({ where: { status: PrescriptionStatus.PENDING } }),
      // "completed" = reviewed and running (ACTIVE) or finished (ENDED).
      this.prisma.prescription.count({ where: { status: { in: [PrescriptionStatus.ACTIVE, PrescriptionStatus.ENDED] } } }),
      this.prisma.prescription.count({ where: { status: PrescriptionStatus.REJECTED } }),
      this.prisma.prescription.findMany({
        orderBy: { createdAt: 'desc' },
        take: RECENT_LIMIT,
        select: { id: true, status: true, createdAt: true, user: { select: { id: true, name: true } } },
      }),
      this.prisma.prescription.findMany({
        where: { createdAt: { gte: trendStart, lt: todayEnd } },
        select: { createdAt: true },
      }),
      this.prisma.user.findMany({
        where: { role: Role.USER, createdAt: { gte: trendStart, lt: todayEnd } },
        select: { createdAt: true },
      }),
      this.prisma.medicineDose.count({
        where: { status: DoseStatus.TAKEN, scheduledAt: { gte: adherenceStart, lt: todayEnd } },
      }),
      this.prisma.medicineDose.count({
        where: { status: DoseStatus.MISSED, scheduledAt: { gte: adherenceStart, lt: todayEnd } },
      }),
      // Overdue but not yet flipped by the background job: still a miss.
      this.prisma.medicineDose.count({
        where: { status: DoseStatus.PENDING, scheduledAt: { gte: adherenceStart, lt: cutoff } },
      }),
      this.prisma.notice.count({
        where: {
          status: NoticeStatus.PUBLISHED,
          // Scheduled notices (no publishedAt yet) aren't live.
          publishedAt: { not: null, lte: now },
          OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
        },
      }),
      this.prisma.healthSuggestionRule.count({ where: { enabled: true } }),
      this.prisma.healthSuggestion.count({ where: { status: SuggestionStatus.DRAFT } }),
      this.prisma.notice.count({ where: { status: NoticeStatus.PENDING_APPROVAL } }),
    ]);

    const missedTotal = missed + overduePending;
    const resolved = taken + missedTotal;

    return {
      generatedAt: now.toISOString(),
      totals: {
        users,
        families,
        prescriptions: { total: pending + completed + rejected, pending, completed, rejected },
      },
      recentPrescriptions: recent,
      analytics: {
        prescriptionsPerDay: this.bucketByDay(prescriptionDates.map((r) => r.createdAt), todayStart),
        newUsersPerDay: this.bucketByDay(userDates.map((r) => r.createdAt), todayStart),
        doses7d: {
          taken,
          missed: missedTotal,
          // null (not 0%) when there is nothing to measure yet.
          adherencePercent: resolved === 0 ? null : Math.round((taken / resolved) * 100),
        },
        liveNotices,
        activeRules,
        aiSuggestionsAwaitingReview: draftSuggestions,
        noticesAwaitingApproval,
      },
    };
  }

  /** Counts per app-timezone calendar day for the last TREND_DAYS days, zero-filled, oldest first. */
  private bucketByDay(dates: Date[], todayStart: Date) {
    const offsetMs = appUtcOffsetMinutes() * 60_000;
    const days: { date: string; count: number }[] = [];
    const index = new Map<string, number>();
    for (let i = TREND_DAYS - 1; i >= 0; i--) {
      const dayStart = addAppDays(todayStart, -i);
      const key = new Date(dayStart.getTime() + offsetMs).toISOString().slice(0, 10);
      index.set(key, days.length);
      days.push({ date: key, count: 0 });
    }
    for (const d of dates) {
      const key = new Date(d.getTime() + offsetMs).toISOString().slice(0, 10);
      const i = index.get(key);
      if (i !== undefined) days[i].count++;
    }
    return days;
  }
}
