import { ConflictException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { DoseStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { computeDisplayStatus, isTakenLate, missedCutoff, missedGraceMinutes } from './lib/dose-status.util';
import { addAppDays, appDayBounds } from '../common/utils/time.util';
import { ErrorCode, withCode } from '../common/filters/error-codes';
import { TAKEN_CLOCK_TOLERANCE_MS, takenWindow } from './lib/taken-window';

@Injectable()
export class MedicineScheduleService {
  constructor(private readonly prisma: PrismaService) {}

  /** All currently-active routines for the user (for a "my medicines" list). */
  async getActiveRoutines(userId: string) {
    return this.prisma.medicineRoutine.findMany({
      where: { userId, active: true },
      orderBy: { startDate: 'asc' },
    });
  }

  async getRoutineDetail(userId: string, routineId: string) {
    await this.sweepMissedDoses(userId);
    const routine = await this.prisma.medicineRoutine.findFirst({
      where: { id: routineId, userId },
      include: { doses: { orderBy: { scheduledAt: 'asc' } } },
    });
    if (!routine) return null;
    return { ...routine, doses: routine.doses.map((d) => this.withDisplayStatus(d)) };
  }

  /** Doses scheduled for the caller's local "today" (interpreted in the app timezone, see time.util.ts). */
  async getTodaysSchedule(userId: string) {
    await this.sweepMissedDoses(userId);
    const { start, end } = this.dayBounds(new Date());
    const doses = await this.prisma.medicineDose.findMany({
      where: { userId, scheduledAt: { gte: start, lt: end } },
      include: { routine: true },
      orderBy: { scheduledAt: 'asc' },
    });
    return doses.map((d) => this.withDisplayStatus(d));
  }

  /** Upcoming doses beyond today, capped to a window so the response stays bounded. */
  async getUpcomingDoses(userId: string, days = 7) {
    await this.sweepMissedDoses(userId);
    const { end: todayEnd } = this.dayBounds(new Date());
    const windowEnd = addAppDays(todayEnd, days);

    const doses = await this.prisma.medicineDose.findMany({
      where: { userId, scheduledAt: { gte: todayEnd, lt: windowEnd } },
      include: { routine: true },
      orderBy: { scheduledAt: 'asc' },
    });
    return doses.map((d) => this.withDisplayStatus(d));
  }

  /** Single dose, with ownership enforced — used before/after marking taken. */
  async getDoseDetail(userId: string, doseId: string) {
    await this.sweepMissedDoses(userId);
    const dose = await this.prisma.medicineDose.findUnique({
      where: { id: doseId },
      include: { routine: true },
    });
    if (!dose) throw new NotFoundException('Dose not found');
    if (dose.userId !== userId) {
      // 404 rather than 403: don't confirm to a caller that a dose ID
      // belonging to someone else exists at all.
      throw new NotFoundException('Dose not found');
    }
    return this.withDisplayStatus(dose);
  }

  /** Past doses, most recent first — for a simple dose-history view. */
  async getDoseHistory(userId: string, from: Date, to: Date) {
    await this.sweepMissedDoses(userId);
    const doses = await this.prisma.medicineDose.findMany({
      where: { userId, scheduledAt: { gte: from, lte: to } },
      include: { routine: true },
      orderBy: { scheduledAt: 'desc' },
    });
    return doses.map((d) => this.withDisplayStatus(d));
  }

  /**
   * Marks a dose TAKEN. Idempotent by design so a retried sync operation
   * (dropped ack, app killed mid-request, etc.) can never double-log or
   * error out:
   *  - already TAKEN → return the existing row unchanged (the first
   *    write wins; a retry re-sending the same `takenAt` is a no-op).
   *  - PENDING or MISSED → transition to TAKEN. MISSED is not terminal
   *    here on purpose: a user is allowed to confirm "I did take it"
   *    after the system auto-marked it missed.
   *  - SKIPPED is left alone; there's no product flow for un-skipping.
   * Only inside the dose's window ([takenWindow]): not before its time
   * (DOSE_NOT_DUE), not later than 1 h before the medicine's next dose
   * (DOSE_WINDOW_CLOSED). The app's own `takenAt` (an offline tap synced
   * later) is what is checked.
   * Round 14: taken after the patient's family-alert time = Late (takenLate);
   * [givenById] = the caregiver who marked it ("I gave it"), else the patient.
   */
  async markDoseTaken(userId: string, doseId: string, takenAt?: string, givenById?: string) {
    const dose = await this.prisma.medicineDose.findUnique({ where: { id: doseId } });
    if (!dose) throw new NotFoundException('Dose not found');
    if (dose.userId !== userId) throw new NotFoundException('Dose not found');

    if (dose.status === DoseStatus.TAKEN) {
      return this.getDoseDetail(userId, doseId);
    }
    if (dose.status === DoseStatus.SKIPPED) {
      throw new ForbiddenException('This dose was skipped and cannot be marked taken');
    }

    const at = takenAt ? new Date(takenAt) : new Date();
    const [routine, next] = await Promise.all([
      this.prisma.medicineRoutine.findUnique({
        where: { id: dose.routineId },
        select: { scheduleTimes: true, intervalDays: true },
      }),
      this.prisma.medicineDose.findFirst({
        where: { routineId: dose.routineId, scheduledAt: { gt: dose.scheduledAt } },
        orderBy: { scheduledAt: 'asc' },
        select: { scheduledAt: true },
      }),
    ]);
    const window = takenWindow(dose, routine ?? { scheduleTimes: null, intervalDays: 1 }, next?.scheduledAt ?? null);
    if (at.getTime() < window.opensAt.getTime() - TAKEN_CLOCK_TOLERANCE_MS) {
      throw withCode(new ConflictException('This dose is not due yet'), ErrorCode.DOSE_NOT_DUE);
    }
    if (at > window.closesAt) {
      throw withCode(new ConflictException('It is too late to mark this dose taken'), ErrorCode.DOSE_WINDOW_CLOSED);
    }

    const grace = await this.graceMinutes(userId);
    await this.prisma.medicineDose.update({
      where: { id: doseId },
      data: {
        status: DoseStatus.TAKEN,
        takenAt: at,
        takenLate: isTakenLate(dose.scheduledAt, at, grace),
        takenById: givenById && givenById !== userId ? givenById : null,
      },
    });

    return this.getDoseDetail(userId, doseId);
  }

  /**
   * Routines (and their doses) created/updated since `since` — lets the
   * mobile sync engine pull only what changed rather than the full
   * dataset every time. `since` is compared against `updatedAt`.
   */
  async getChangesSince(userId: string, since: Date) {
    await this.sweepMissedDoses(userId);
    const routines = await this.prisma.medicineRoutine.findMany({
      where: { userId, updatedAt: { gt: since } },
      include: { doses: { orderBy: { scheduledAt: 'asc' } } },
      orderBy: { updatedAt: 'asc' },
    });
    return {
      routines: routines.map((r) => ({ ...r, doses: r.doses.map((d) => this.withDisplayStatus(d)) })),
      syncedAt: new Date(),
    };
  }

  /**
   * Deterministic, idempotent sweep: any dose still PENDING whose
   * scheduled time is more than the grace window in the past becomes
   * MISSED. Run lazily at the start of every read rather than via a
   * background cron — this project has no job-scheduler infra to reuse,
   * and "recompute on read" needs none while producing the exact same
   * end state (a dose scheduled for a moment in the past is either taken
   * or it isn't, regardless of when the sweep runs).
   */
  private async sweepMissedDoses(userId: string): Promise<void> {
    const grace = await this.graceMinutes(userId);
    await this.prisma.medicineDose.updateMany({
      where: {
        userId,
        status: DoseStatus.PENDING,
        scheduledAt: { lt: missedCutoff(new Date(), grace) },
      },
      data: { status: DoseStatus.MISSED },
    });
  }

  /** The patient's own family-alert time (Round 14), else the .env default. */
  async graceMinutes(userId: string): Promise<number> {
    const user = await this.prisma.user.findUnique({ where: { id: userId }, select: { familyAlertMinutes: true } });
    return user?.familyAlertMinutes ?? missedGraceMinutes();
  }

  private withDisplayStatus<T extends { status: DoseStatus; scheduledAt: Date }>(dose: T) {
    return { ...dose, displayStatus: computeDisplayStatus(dose.status, dose.scheduledAt) };
  }

  private dayBounds(reference: Date): { start: Date; end: Date } {
    // App timezone (Asia/Dhaka), not the server's — see time.util.ts.
    return appDayBounds(reference);
  }
}
