import { BadRequestException, Injectable } from '@nestjs/common';
import { PrescriptionMedicine } from '@prisma/client';
import { addAppDays, atAppTime, startOfAppDay } from '../../common/utils/time.util';

export interface GeneratedDose {
  scheduledAt: Date;
}

export interface GeneratedRoutine {
  medicineName: string;
  dosage: string;
  frequency: string;
  startDate: Date;
  endDate: Date | null;
  prescriptionMedicineId: string;
  doses: GeneratedDose[];
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
   *   timesPerDay/scheduleTimes/durationDays already validated present —
   *   see `PrescriptionsService.assertMedicinesReadyForCompletion`)
   * @param completedAt the moment the prescription was completed; used
   *   as the administrative default start date when none was given
   */
  generate(medicine: PrescriptionMedicine, completedAt: Date): GeneratedRoutine {
    const timesPerDay = medicine.timesPerDay;
    const durationDays = medicine.durationDays;
    const scheduleTimes = this.parseScheduleTimes(medicine.scheduleTimes);

    if (!timesPerDay || !durationDays || scheduleTimes.length === 0) {
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
    // endDate is inclusive of the last dosing day.
    const endDate = addAppDays(startDate, durationDays - 1);

    const doses: GeneratedDose[] = [];
    for (let dayOffset = 0; dayOffset < durationDays; dayOffset++) {
      const day = addAppDays(startDate, dayOffset);
      for (const time of scheduleTimes) {
        doses.push({ scheduledAt: atAppTime(day, time) });
      }
    }

    return {
      medicineName: medicine.medicineName,
      dosage: medicine.dosage,
      frequency: medicine.frequency,
      startDate,
      endDate,
      prescriptionMedicineId: medicine.id,
      doses,
    };
  }

  private parseScheduleTimes(raw: string | null): string[] {
    if (!raw) return [];
    try {
      const parsed = JSON.parse(raw);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
}
