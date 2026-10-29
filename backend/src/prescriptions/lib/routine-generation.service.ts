import { BadRequestException, Injectable } from '@nestjs/common';
import { PrescriptionMedicine } from '@prisma/client';
import { addAppDays, atAppTime, startOfAppDay } from '../../common/utils/time.util';

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
  /** Stored on the routine so the rolling job can continue it. */
  scheduleTimes: string;
  /** Doses exist up to (excluding) this instant. */
  generatedUntil: Date;
  doses: GeneratedDose[];
}

/** One dose per schedule time on every app-timezone day in [fromDay, toDayExclusive). */
export function dosesForDays(scheduleTimes: string[], fromDay: Date, toDayExclusive: Date): GeneratedDose[] {
  const doses: GeneratedDose[] = [];
  for (let day = fromDay; day < toDayExclusive; day = addAppDays(day, 1)) {
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

    const startDate = startOfAppDay(medicine.startDate ?? completedAt);
    // endDate is inclusive of the last dosing day; none for a continuous line.
    const endDate = medicine.continuous || !durationDays ? null : addAppDays(startDate, durationDays - 1);
    const limit = generationLimit(endDate, completedAt);
    // A start beyond the horizon: nothing yet, the rolling job begins there.
    const generatedUntil = limit > startDate ? limit : startDate;

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
      scheduleTimes: JSON.stringify(scheduleTimes),
      generatedUntil,
      doses: dosesForDays(scheduleTimes, startDate, generatedUntil),
    };
  }
}
