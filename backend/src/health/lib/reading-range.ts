import { HealthLimits, HealthRecordType, RangeState, SugarContext } from '@prisma/client';

/**
 * Round 15 reading rules (owner, 2026-11-11). The same rules live in the app
 * (features/care/domain/reading_rules.dart) so a reading is judged offline.
 *
 * - Range: only against the limits the user or caregiver saved (the doctor's
 *   numbers). A kind with no saved limit has no range state (NULL): no chip,
 *   no family alert.
 * - Crisis: fixed safety levels, saved limits or not. BP 180/120 or higher
 *   (160/110 at most in pregnancy; the user may change the BP level), sugar
 *   below 3.0 mmol/L (fixed).
 */

export const MG_PER_MMOL = 18;
export const SUGAR_CRISIS_BELOW_MMOL = 3.0;
export const BP_CRISIS_DEFAULT = { systolic: 180, diastolic: 120 };
export const BP_CRISIS_PREGNANCY_MAX = { systolic: 160, diastolic: 110 };

export type Limits = Pick<
  HealthLimits,
  | 'fastingLow'
  | 'fastingHigh'
  | 'afterFoodHigh'
  | 'lowSugar'
  | 'bpSystolicHigh'
  | 'bpDiastolicHigh'
  | 'bpSystolicLow'
  | 'bpCrisisSystolic'
  | 'bpCrisisDiastolic'
  | 'feverAboveF'
>;

export interface ReadingValues {
  type: HealthRecordType;
  numericValue?: number | null;
  systolic?: number | null;
  diastolic?: number | null;
  sugarContext?: SugarContext | null;
}

/** The BP level at which the crisis sheet opens. */
export function bpCrisisLevel(limits: Limits | null, pregnant: boolean) {
  let systolic = limits?.bpCrisisSystolic ?? BP_CRISIS_DEFAULT.systolic;
  let diastolic = limits?.bpCrisisDiastolic ?? BP_CRISIS_DEFAULT.diastolic;
  if (pregnant) {
    systolic = Math.min(systolic, BP_CRISIS_PREGNANCY_MAX.systolic);
    diastolic = Math.min(diastolic, BP_CRISIS_PREGNANCY_MAX.diastolic);
  }
  return { systolic, diastolic };
}

export function isCrisis(r: ReadingValues, limits: Limits | null, pregnant: boolean): boolean {
  if (r.type === HealthRecordType.BLOOD_PRESSURE && r.systolic != null && r.diastolic != null) {
    const level = bpCrisisLevel(limits, pregnant);
    return r.systolic >= level.systolic || r.diastolic >= level.diastolic;
  }
  if (r.type === HealthRecordType.BLOOD_SUGAR && r.numericValue != null) {
    return r.numericValue < SUGAR_CRISIS_BELOW_MMOL;
  }
  return false;
}

/** In / below / above the saved limits; null when no limit applies. */
export function rangeStateOf(r: ReadingValues, limits: Limits | null): RangeState | null {
  if (!limits) return null;
  switch (r.type) {
    case HealthRecordType.BLOOD_PRESSURE: {
      const { bpSystolicHigh: sysHi, bpDiastolicHigh: diaHi, bpSystolicLow: sysLo } = limits;
      if (r.systolic == null || r.diastolic == null) return null;
      if (sysHi == null && diaHi == null && sysLo == null) return null;
      if (sysLo != null && r.systolic < sysLo) return RangeState.BELOW;
      if ((sysHi != null && r.systolic >= sysHi) || (diaHi != null && r.diastolic >= diaHi)) return RangeState.ABOVE;
      return RangeState.IN_RANGE;
    }
    case HealthRecordType.BLOOD_SUGAR: {
      const v = r.numericValue;
      if (v == null) return null;
      const fasting = r.sugarContext === SugarContext.FASTING;
      const low = fasting ? (limits.fastingLow ?? limits.lowSugar) : limits.lowSugar;
      const high = fasting ? limits.fastingHigh : limits.afterFoodHigh;
      if (low == null && high == null && limits.lowSugar == null) return null;
      if (limits.lowSugar != null && v < limits.lowSugar) return RangeState.BELOW;
      if (low != null && v < low) return RangeState.BELOW;
      if (high != null && v > high) return RangeState.ABOVE;
      return RangeState.IN_RANGE;
    }
    case HealthRecordType.TEMPERATURE: {
      if (r.numericValue == null || limits.feverAboveF == null) return null;
      return r.numericValue > limits.feverAboveF ? RangeState.ABOVE : RangeState.IN_RANGE;
    }
    default:
      return null;
  }
}
