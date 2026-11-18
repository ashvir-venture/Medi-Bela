import { PrescriptionMedicine } from '@prisma/client';
import { appWeekday, dosesForDays, parseWeekdays, planSchedule, RoutineGenerationService } from '../routine-generation.service';
import { startOfAppDay } from '../../../common/utils/time.util';

// Dhaka (+06:00). 12 Jan 2026 was a Monday.
const monday = startOfAppDay(new Date('2026-01-12T06:00:00.000Z'));

describe('Round 18: certain days and only when needed', () => {
  it('knows the weekday of an app-timezone day (Dhaka midnight is the day before in UTC)', () => {
    expect(appWeekday(monday)).toBe(1);
    expect(monday.toISOString()).toBe('2026-01-11T18:00:00.000Z');
  });

  it('certain days: doses only on the chosen weekdays', () => {
    // Sat (6), Sun (0) and Mon (1), as in the client's example.
    const next14 = new Date(monday.getTime() + 14 * 86_400_000);
    const doses = dosesForDays(['09:00'], monday, next14, { days: 1, anchor: monday, weekdays: [6, 0, 1] });
    const days = doses.map((d) => appWeekday(startOfAppDay(d.scheduledAt)));
    expect(doses).toHaveLength(6);
    expect(new Set(days)).toEqual(new Set([0, 1, 6]));
  });

  it('planSchedule keeps the weekdays (and only future times)', () => {
    const now = new Date(monday.getTime() + 10 * 3_600_000); // Monday 10:00 Dhaka
    const plan = planSchedule(
      { scheduleTimes: ['09:00', '21:00'], startDate: null, durationDays: 7, continuous: false, weekdays: [1, 3] },
      now,
    );
    // Mon 21:00 and Wed 09:00 / 21:00 (Mon 09:00 is already past).
    expect(plan.doses.map((d) => d.scheduledAt.toISOString())).toEqual([
      '2026-01-12T15:00:00.000Z',
      '2026-01-14T03:00:00.000Z',
      '2026-01-14T15:00:00.000Z',
    ]);
  });

  it('reads stored weekdays safely', () => {
    expect(parseWeekdays('[6,0,1,1]')).toEqual([0, 1, 6]);
    expect(parseWeekdays('[9,"x"]')).toEqual([]);
    expect(parseWeekdays(null)).toEqual([]);
    expect(parseWeekdays('not json')).toEqual([]);
  });

  it('an "only when needed" prescription line becomes a routine with no times and no doses', () => {
    const line = {
      id: 'pm1',
      medicineName: 'Napa',
      dosage: '500 mg',
      frequency: 'when needed',
      timesPerDay: null,
      scheduleTimes: null,
      durationDays: null,
      continuous: false,
      startDate: null,
      strength: '500 mg',
      doseAmount: '1 tablet',
      mealTimingId: null,
      formId: null,
      intervalDays: 1,
      asNeeded: true,
      maxPerDay: 3,
      minGapHours: 6,
    } as unknown as PrescriptionMedicine;
    const r = new RoutineGenerationService().generate(line, new Date('2026-01-12T04:00:00.000Z'));
    expect(r).toMatchObject({ asNeeded: true, maxPerDay: 3, minGapHours: 6, scheduleTimes: null, generatedUntil: null, endDate: null });
    expect(r.doses).toEqual([]);
  });
});
