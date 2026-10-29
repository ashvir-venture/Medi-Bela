import { BadRequestException } from '@nestjs/common';
import { PrescriptionMedicine } from '@prisma/client';
import { ROLLING_HORIZON_DAYS, RoutineGenerationService, dosesForDays } from '../routine-generation.service';

function makeMedicine(overrides: Partial<PrescriptionMedicine> = {}): PrescriptionMedicine {
  return {
    id: 'med-1',
    prescriptionId: 'presc-1',
    medicineName: 'Paracetamol',
    dosage: '500mg',
    frequency: 'twice daily',
    duration: '5 days',
    instructions: 'after meal',
    timesPerDay: 2,
    scheduleTimes: JSON.stringify(['08:00', '20:00']),
    durationDays: 5,
    startDate: null,
    verified: true,
    verifiedById: 'admin-1',
    verifiedAt: new Date(),
    createdAt: new Date(),
    updatedAt: new Date(),
    ...overrides,
  } as PrescriptionMedicine;
}

describe('RoutineGenerationService', () => {
  const service = new RoutineGenerationService();
  const completedAt = new Date('2026-01-10T12:00:00.000Z');

  it('generates one dose per scheduled time per day, for durationDays', () => {
    const routine = service.generate(makeMedicine(), completedAt);
    expect(routine.doses).toHaveLength(10); // 2 times/day * 5 days
  });

  // The app timezone is Asia/Dhaka (UTC+6), independent of the server's TZ.
  // 2026-01-10T12:00Z is 18:00 on 10 Jan in Dhaka, so the routine starts at
  // Dhaka midnight of 10 Jan == 2026-01-09T18:00Z.
  it('defaults startDate to the completion date (at app-timezone midnight) when none is given', () => {
    const routine = service.generate(makeMedicine(), completedAt);
    expect(routine.startDate.toISOString()).toBe('2026-01-09T18:00:00.000Z');
  });

  it('does not depend on the server timezone (a completion just after UTC midnight is still the same Dhaka day)', () => {
    const lateUtc = new Date('2026-01-10T23:30:00.000Z'); // 05:30 on 11 Jan in Dhaka
    const routine = service.generate(makeMedicine(), lateUtc);
    expect(routine.startDate.toISOString()).toBe('2026-01-10T18:00:00.000Z');
  });

  it('uses an explicit startDate when provided instead of the completion date', () => {
    const explicitStart = new Date('2026-02-01T00:00:00.000Z'); // 06:00 on 1 Feb in Dhaka
    const routine = service.generate(makeMedicine({ startDate: explicitStart }), completedAt);
    expect(routine.startDate.toISOString()).toBe('2026-01-31T18:00:00.000Z'); // Dhaka midnight, 1 Feb
  });

  it('computes endDate as startDate + (durationDays - 1)', () => {
    const routine = service.generate(makeMedicine({ durationDays: 3 }), completedAt);
    expect(routine.endDate?.toISOString()).toBe('2026-01-11T18:00:00.000Z'); // Dhaka midnight, 12 Jan
  });

  it('sets each dose to the correct clock time on the correct day', () => {
    const routine = service.generate(makeMedicine({ durationDays: 2 }), completedAt);
    const times = routine.doses.map((d) => d.scheduledAt.toISOString());
    // 08:00 and 20:00 *Dhaka time* on 10 and 11 Jan.
    expect(times).toEqual([
      '2026-01-10T02:00:00.000Z',
      '2026-01-10T14:00:00.000Z',
      '2026-01-11T02:00:00.000Z',
      '2026-01-11T14:00:00.000Z',
    ]);
  });

  it('is deterministic: identical inputs always produce identical output', () => {
    const a = service.generate(makeMedicine(), completedAt);
    const b = service.generate(makeMedicine(), completedAt);
    expect(a.doses.map((d) => d.scheduledAt.toISOString())).toEqual(
      b.doses.map((d) => d.scheduledAt.toISOString()),
    );
    expect(a.startDate).toEqual(b.startDate);
    expect(a.endDate).toEqual(b.endDate);
  });

  it('throws rather than inventing a schedule when structured data is missing', () => {
    expect(() => service.generate(makeMedicine({ timesPerDay: null }), completedAt)).toThrow(
      BadRequestException,
    );
    expect(() => service.generate(makeMedicine({ durationDays: null }), completedAt)).toThrow(
      BadRequestException,
    );
    expect(() =>
      service.generate(makeMedicine({ scheduleTimes: null }), completedAt),
    ).toThrow(BadRequestException);
  });

  it('throws when scheduleTimes length does not match timesPerDay', () => {
    expect(() =>
      service.generate(
        makeMedicine({ timesPerDay: 3, scheduleTimes: JSON.stringify(['08:00', '20:00']) }),
        completedAt,
      ),
    ).toThrow(BadRequestException);
  });
});

describe('RoutineGenerationService - rolling generation (Round 4)', () => {
  const service = new RoutineGenerationService();
  const completedAt = new Date('2026-01-10T12:00:00.000Z'); // 10 Jan in Dhaka

  it('creates only ROLLING_HORIZON_DAYS of doses for a long course and records where it stopped', () => {
    const routine = service.generate(makeMedicine({ durationDays: 30 }), completedAt);
    expect(routine.doses).toHaveLength(2 * ROLLING_HORIZON_DAYS);
    expect(routine.endDate?.toISOString()).toBe('2026-02-07T18:00:00.000Z'); // 8 Feb, the 30th day
    expect(routine.generatedUntil.toISOString()).toBe('2026-01-23T18:00:00.000Z'); // 24 Jan, horizon
  });

  it('a short course is generated in full and stops the day after it ends', () => {
    const routine = service.generate(makeMedicine({ durationDays: 5 }), completedAt);
    expect(routine.doses).toHaveLength(10);
    expect(routine.generatedUntil.toISOString()).toBe('2026-01-14T18:00:00.000Z'); // 15 Jan
  });

  it('a continuous line has no end date and needs no durationDays', () => {
    const routine = service.generate(makeMedicine({ durationDays: null, continuous: true } as any), completedAt);
    expect(routine.endDate).toBeNull();
    expect(routine.doses).toHaveLength(2 * ROLLING_HORIZON_DAYS);
  });

  it('a start beyond the horizon creates nothing yet; the job starts at the start date', () => {
    const start = new Date('2026-03-01T00:00:00.000Z');
    const routine = service.generate(makeMedicine({ startDate: start, durationDays: 5 }), completedAt);
    expect(routine.doses).toHaveLength(0);
    expect(routine.generatedUntil).toEqual(routine.startDate);
  });

  it('keeps what the job needs on the routine', () => {
    const routine = service.generate(
      makeMedicine({ strength: '500 mg', doseAmount: '1 tablet', mealTimingId: 2 } as any),
      completedAt,
    );
    expect(routine).toMatchObject({
      strength: '500 mg',
      doseAmount: '1 tablet',
      mealTimingId: 2,
      scheduleTimes: JSON.stringify(['08:00', '20:00']),
    });
  });

  it('dosesForDays covers [from, to) by app-timezone day', () => {
    const from = new Date('2026-01-09T18:00:00.000Z');
    expect(dosesForDays(['08:00'], from, from)).toEqual([]);
    expect(dosesForDays(['08:00', '20:00'], from, new Date('2026-01-11T18:00:00.000Z'))).toHaveLength(4);
  });
});
