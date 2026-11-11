import { HealthRecordType, RangeState, SugarContext } from '@prisma/client';
import { bpCrisisLevel, isCrisis, Limits, rangeStateOf } from '../reading-range';

const none: Limits = {
  fastingLow: null,
  fastingHigh: null,
  afterFoodHigh: null,
  lowSugar: null,
  bpSystolicHigh: null,
  bpDiastolicHigh: null,
  bpSystolicLow: null,
  bpCrisisSystolic: null,
  bpCrisisDiastolic: null,
  feverAboveF: null,
};
const doctor: Limits = {
  ...none,
  fastingLow: 4.4,
  fastingHigh: 7.0,
  afterFoodHigh: 10.0,
  lowSugar: 3.9,
  bpSystolicHigh: 140,
  bpDiastolicHigh: 90,
  bpSystolicLow: 90,
  feverAboveF: 100.4,
};
const bp = (systolic: number, diastolic: number) => ({ type: HealthRecordType.BLOOD_PRESSURE, systolic, diastolic });
const sugar = (v: number, ctx: SugarContext) => ({ type: HealthRecordType.BLOOD_SUGAR, numericValue: v, sugarContext: ctx });

describe('reading range (owner rules 2026-11-11)', () => {
  it('has no range state without saved limits', () => {
    expect(rangeStateOf(bp(190, 125), null)).toBeNull();
    expect(rangeStateOf(bp(190, 125), none)).toBeNull();
    expect(rangeStateOf(sugar(2.5, SugarContext.FASTING), none)).toBeNull();
  });

  it('judges BP against the saved numbers', () => {
    expect(rangeStateOf(bp(130, 85), doctor)).toBe(RangeState.IN_RANGE);
    expect(rangeStateOf(bp(140, 80), doctor)).toBe(RangeState.ABOVE);
    expect(rangeStateOf(bp(120, 90), doctor)).toBe(RangeState.ABOVE);
    expect(rangeStateOf(bp(85, 60), doctor)).toBe(RangeState.BELOW);
  });

  it('judges sugar by when it was taken', () => {
    expect(rangeStateOf(sugar(6.5, SugarContext.FASTING), doctor)).toBe(RangeState.IN_RANGE);
    expect(rangeStateOf(sugar(7.5, SugarContext.FASTING), doctor)).toBe(RangeState.ABOVE);
    expect(rangeStateOf(sugar(4.2, SugarContext.FASTING), doctor)).toBe(RangeState.BELOW);
    expect(rangeStateOf(sugar(9.5, SugarContext.AFTER_FOOD), doctor)).toBe(RangeState.IN_RANGE);
    expect(rangeStateOf(sugar(10.5, SugarContext.RANDOM), doctor)).toBe(RangeState.ABOVE);
    expect(rangeStateOf(sugar(3.5, SugarContext.AFTER_FOOD), doctor)).toBe(RangeState.BELOW);
  });

  it('marks fever only above the saved limit', () => {
    const t = (v: number) => ({ type: HealthRecordType.TEMPERATURE, numericValue: v });
    expect(rangeStateOf(t(101), doctor)).toBe(RangeState.ABOVE);
    expect(rangeStateOf(t(99), doctor)).toBe(RangeState.IN_RANGE);
    expect(rangeStateOf(t(101), none)).toBeNull();
  });

  it('opens the crisis sheet at fixed levels without limits', () => {
    expect(isCrisis(bp(180, 100), null, false)).toBe(true);
    expect(isCrisis(bp(170, 120), null, false)).toBe(true);
    expect(isCrisis(bp(179, 119), null, false)).toBe(false);
    expect(isCrisis(sugar(2.9, SugarContext.RANDOM), null, false)).toBe(true);
    expect(isCrisis(sugar(3.0, SugarContext.RANDOM), null, false)).toBe(false);
  });

  it('uses 160/110 at most in pregnancy, and the user BP level otherwise', () => {
    expect(bpCrisisLevel(null, true)).toEqual({ systolic: 160, diastolic: 110 });
    expect(isCrisis(bp(162, 90), null, true)).toBe(true);
    const own = { ...none, bpCrisisSystolic: 170, bpCrisisDiastolic: 115 };
    expect(bpCrisisLevel(own, false)).toEqual({ systolic: 170, diastolic: 115 });
    expect(bpCrisisLevel({ ...none, bpCrisisSystolic: 200, bpCrisisDiastolic: 130 }, true)).toEqual({
      systolic: 160,
      diastolic: 110,
    });
  });
});
