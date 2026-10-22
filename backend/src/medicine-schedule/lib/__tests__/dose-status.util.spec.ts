import { DoseStatus } from '@prisma/client';
import { computeDisplayStatus, missedCutoff } from '../dose-status.util';

describe('computeDisplayStatus', () => {
  const now = new Date('2026-03-01T12:00:00.000Z');

  it('shows a PENDING dose in the future as UPCOMING', () => {
    const future = new Date('2026-03-01T18:00:00.000Z');
    expect(computeDisplayStatus(DoseStatus.PENDING, future, now)).toBe('UPCOMING');
  });

  it('shows a PENDING dose at/after its scheduled time as DUE', () => {
    const past = new Date('2026-03-01T08:00:00.000Z');
    expect(computeDisplayStatus(DoseStatus.PENDING, past, now)).toBe('DUE');
    expect(computeDisplayStatus(DoseStatus.PENDING, now, now)).toBe('DUE');
  });

  it('passes through terminal statuses unchanged regardless of time', () => {
    const future = new Date('2026-03-05T00:00:00.000Z');
    expect(computeDisplayStatus(DoseStatus.TAKEN, future, now)).toBe('TAKEN');
    expect(computeDisplayStatus(DoseStatus.MISSED, future, now)).toBe('MISSED');
    expect(computeDisplayStatus(DoseStatus.SKIPPED, future, now)).toBe('SKIPPED');
  });
});

describe('missedCutoff', () => {
  const originalEnv = process.env.DOSE_MISSED_GRACE_MINUTES;

  afterEach(() => {
    process.env.DOSE_MISSED_GRACE_MINUTES = originalEnv;
  });

  it('defaults to 120 minutes before the reference time', () => {
    delete process.env.DOSE_MISSED_GRACE_MINUTES;
    const reference = new Date('2026-03-01T12:00:00.000Z');
    expect(missedCutoff(reference).toISOString()).toBe('2026-03-01T10:00:00.000Z');
  });

  it('respects a configured grace period', () => {
    process.env.DOSE_MISSED_GRACE_MINUTES = '30';
    const reference = new Date('2026-03-01T12:00:00.000Z');
    expect(missedCutoff(reference).toISOString()).toBe('2026-03-01T11:30:00.000Z');
  });

  it('ignores invalid configuration and falls back to the default', () => {
    process.env.DOSE_MISSED_GRACE_MINUTES = 'not-a-number';
    const reference = new Date('2026-03-01T12:00:00.000Z');
    expect(missedCutoff(reference).toISOString()).toBe('2026-03-01T10:00:00.000Z');
  });
});
