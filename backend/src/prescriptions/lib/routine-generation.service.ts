import { BadRequestException, Injectable } from '@nestjs/common';
import { PrescriptionMedicine } from '@prisma/client';
import { addAppDays, appUtcOffsetMinutes, atAppTime, startOfAppDay } from '../../common/utils/time.util';

/**
 * Doses are generated on a rolling basis: only this many days ahead of
 * "now", then RollingDoseJob keeps extending each routine. This keeps the
 * dose table small for long or open-ended ("continuous") courses.
 */
export const ROLLING_HORIZON_DAYS = 14;

export interface GeneratedDose {
  scheduledAt: Date;
}

export interface GeneratedRoutine {
  medicineName: string;
  dosage: string;
  frequency: string;
  startDate: Date;
  /** Null for a continuous line (no end date). */
  endDate: Date | null;
  prescriptionMedicineId: string;
  strength: string | null;
  doseAmount: string | null;
  mealTimingId: number | null;
  formId: number | null;
  /** Every N days (1 = every day), counted from startDate. */
  intervalDays: number;
  /** Stored on the routine so the rolling job can continue it (null: as needed). */
  scheduleTimes: string | null;
  /** Doses exist up to (excluding) this instant (null: as needed). */
  generatedUntil: Date | null;
  /** Round 18: an "only when needed" line. */
  asNeeded?: boolean;
  maxPerDay?: number | null;
  minGapHours?: number | null;
  doses: GeneratedDose[];
}

const DAY_MS = 24 * 60 * 60 * 1000;

/** Every N days: a dosing day is a whole multiple of N days after the first one. */
export interface DoseInterval {
  days: number;
  /** Start of the routine's first dosing day (app timezone). */
  anchor: Date;
  /**
   * Round 18 (client point 1b, "Certain days"): only on these weekdays of
   * the app-timezone day, 0 = Sunday ... 6 = Saturday. Empty / missing =
   * every day (or every N days).
   */
  weekdays?: number[];
}

/** 0 = Sunday ... 6 = Saturday, of an app-timezone day start. */
export function appWeekday(dayStart: Date, offsetMinutes = appUtcOffsetMinutes()): number {
  return new Date(dayStart.getTime() + offsetMinutes * 60_000).getUTCDay();
}

/** Round 18: routines.weekdays (JSON "[0,3,5]") → numbers 0-6, sorted; [] when unset. */
export function parseWeekdays(raw: string | null | undefined): number[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed)
      ? [...new Set(parsed.filter((d) => Number.isInteger(d) && d >= 0 && d <= 6) as number[])].sort()
      : [];
  } catch {
    return [];
  }
}

/**
 * One dose per schedule time on every app-timezone day in
 * [fromDay, toDayExclusive), or only on every Nth day from `interval.anchor`.
 */
export function dosesForDays(
  scheduleTimes: string[],
  fromDay: Date,
  toDayExclusive: Date,
  interval?: DoseInterval,
): GeneratedDose[] {
  const doses: GeneratedDose[] = [];
  const every = interval && interval.days > 1 ? interval : null;
  const weekdays = interval?.weekdays?.length ? new Set(interval.weekdays) : null;
  for (let day = fromDay; day < toDayExclusive; day = addAppDays(day, 1)) {
    if (weekdays && !weekdays.has(appWeekday(day))) continue;
    if (every) {
      const offset = Math.round((day.getTime() - every.anchor.getTime()) / DAY_MS);
      if (offset < 0 || offset % every.days !== 0) continue;
    }
    for (const time of scheduleTimes) {
      doses.push({ scheduledAt: atAppTime(day, time) });
    }
  }
  return doses;
}

/**
 * Where generation stops for now: the end of the course (the day after
 * endDate) or the rolling horizon, whichever comes first.
 */
export function generationLimit(endDate: Date | null, now: Date): Date {
  const horizonEnd = addAppDays(startOfAppDay(now), ROLLING_HORIZON_DAYS);
  if (!endDate) return horizonEnd;
  const afterEnd = addAppDays(endDate, 1);
  return afterEnd < horizonEnd ? afterEnd : horizonEnd;
}

export interface PlannedSchedule {
  startDate: Date;
  endDate: Date | null;
  generatedUntil: Date;
  doses: GeneratedDose[];
}

/**
 * Start, end and first doses of a schedule. The start defaults to today, or
 * to tomorrow for an every-N-days medicine (owner, 2026-10-31); endDate is
 * inclusive of the last day of the course (none when continuous).
 * Shared by prescription routines and self-added ones.
 */
export function planSchedule(
  input: {
    scheduleTimes: string[];
    startDate: Date | null;
    durationDays: number | null;
    continuous: boolean;
    intervalDays?: number;
    /** Round 18: "Certain days" (0 = Sunday ... 6 = Saturday). */
    weekdays?: number[];
  },
  now: Date,
): PlannedSchedule {
  const intervalDays = input.intervalDays ?? 1;
  const startDate = input.startDate
    ? startOfAppDay(input.startDate)
    : addAppDays(startOfAppDay(now), intervalDays > 1 ? 1 : 0);
  const endDate =
    input.continuous || !input.durationDays ? null : addAppDays(startDate, input.durationDays - 1);
  const limit = generationLimit(endDate, now);
  // A start beyond the horizon: nothing yet, the rolling job begins there.
  const generatedUntil = limit > startDate ? limit : startDate;
  // Only times still ahead, by date and time (owner, 2026-10-31): confirming
  // at 15:00 doesn't create that morning's dose, which would show as missed.
  // The course keeps its dates; the rolling job and pause / resume follow the same rule.
  const doses = dosesForDays(input.scheduleTimes, startDate, generatedUntil, {
    days: intervalDays,
    anchor: startDate,
    weekdays: input.weekdays,
  }).filter((d) => d.scheduledAt > now);
  return { startDate, endDate, generatedUntil, doses };
}

export function parseScheduleTimes(raw: string | null): string[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

/**
 * Pure, deterministic transformation of verified `PrescriptionMedicine`
 * rows into `MedicineRoutine` + `MedicineDose` shapes.
 *
 * No AI, no clinical inference, no invented defaults: every value comes
 * either directly from the verified medicine data or from an explicit,
 * documented administrative rule (e.g. "if no start date was given, use
 * the completion date"). Given the same inputs this always produces the
 * same output, which is what makes it safe to re-run/test.
 */
@Injectable()
export class RoutineGenerationService {
  /**
   * @param medicine verified PrescriptionMedicine row (must have
   *   timesPerDay/scheduleTimes, and durationDays unless continuous, already
   *   validated — see `PrescriptionsService.assertMedicinesReadyForCompletion`)
   * @param completedAt the moment the prescription was completed; used
   *   as the administrative default start date when none was given, and as
   *   "now" for the rolling horizon
   */
  generate(medicine: PrescriptionMedicine, completedAt: Date): GeneratedRoutine {
    // Round 18: "only when needed" lines have no times: no doses, nothing to roll.
    if (medicine.asNeeded) {
      const startDate = medicine.startDate ? startOfAppDay(medicine.startDate) : startOfAppDay(completedAt);
      return {
        medicineName: medicine.medicineName,
        dosage: medicine.dosage,
        frequency: medicine.frequency,
        startDate,
        endDate: medicine.durationDays && !medicine.continuous ? addAppDays(startDate, medicine.durationDays - 1) : null,
        prescriptionMedicineId: medicine.id,
        strength: medicine.strength,
        doseAmount: medicine.doseAmount,
        mealTimingId: medicine.mealTimingId,
        formId: medicine.formId,
        intervalDays: 1,
        scheduleTimes: null,
        generatedUntil: null,
        asNeeded: true,
        maxPerDay: medicine.maxPerDay,
        minGapHours: medicine.minGapHours,
        doses: [],
      };
    }
    const timesPerDay = medicine.timesPerDay;
    const durationDays = medicine.durationDays;
    const scheduleTimes = parseScheduleTimes(medicine.scheduleTimes);

    if (!timesPerDay || (!durationDays && !medicine.continuous) || scheduleTimes.length === 0) {
      // Should already have been caught by completion-time validation;
      // this is a defensive guard against generation ever inventing a
      // schedule from incomplete data.
      throw new BadRequestException(
        `Cannot generate a routine for medicine "${medicine.medicineName}": missing structured schedule data`,
      );
    }

    if (scheduleTimes.length !== timesPerDay) {
      throw new BadRequestException(
        `Medicine "${medicine.medicineName}": scheduleTimes count (${scheduleTimes.length}) does not match timesPerDay (${timesPerDay})`,
      );
    }

    const { startDate, endDate, generatedUntil, doses } = planSchedule(
      {
        scheduleTimes,
        startDate: medicine.startDate,
        durationDays,
        continuous: medicine.continuous,
        intervalDays: medicine.intervalDays,
      },
      completedAt,
    );

    return {
      medicineName: medicine.medicineName,
      dosage: medicine.dosage,
      frequency: medicine.frequency,
      startDate,
      endDate,
      prescriptionMedicineId: medicine.id,
      strength: medicine.strength,
      doseAmount: medicine.doseAmount,
      mealTimingId: medicine.mealTimingId,
      formId: medicine.formId,
      intervalDays: medicine.intervalDays,
      scheduleTimes: JSON.stringify(scheduleTimes),
      generatedUntil,
      doses,
    };
  }
}
