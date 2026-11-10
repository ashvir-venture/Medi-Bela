import { effectiveTiming, lastRingEndsMinutes, reminderTiming, timingWarning } from '../reminder-timing';
import { takenWindow } from '../../../medicine-schedule/lib/taken-window';
import { backstopAfterMinutes } from '../../../medicine-schedule/missed-dose-alert.service';
import { testReminderTime } from '../../../prescriptions/prescriptions.service';
import { testCaregiverAlertAfterMs } from '../../../health/test-reminder.job';

const KEYS = [
  'REMINDER_REPEAT_MINUTES',
  'REMINDER_LATER_MINUTES',
  'REMINDER_RINGS',
  'REMINDER_RING_MINUTES',
  'DOSE_MISSED_GRACE_MINUTES',
  'BACKSTOP_AFTER_MINUTES',
  'TAKEN_CLOSES_BEFORE_NEXT_MINUTES',
  'TEST_REMINDER_DAYS',
  'TEST_REMINDER_DEFAULT_DELAY_DAYS',
  'TEST_REMINDER_DEFAULT_TIME',
  'MEDICINE_BOX_LOW_DOSES',
  'APP_SYNC_MINUTES',
];

// Owner, 2026-10-31: every reminder timing comes from .env; changing it there changes the behaviour.
describe('reminder timings from .env', () => {
  const saved: Record<string, string | undefined> = {};
  beforeEach(() => {
    for (const k of KEYS) {
      saved[k] = process.env[k];
      delete process.env[k];
    }
  });
  afterEach(() => {
    for (const k of KEYS) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  });

  it('defaults: 15-minute rings x 4, family at 50, Taken until 1 h before the next, tests 3 days at 08:00', () => {
    expect(reminderTiming()).toEqual({
      repeatMinutes: 15,
      laterMinutes: 15,
      rings: 4,
      ringMinutes: 2,
      missedGraceMinutes: 50,
      backstopAfterMinutes: 15,
      takenClosesBeforeNextMinutes: 60,
      testReminderDays: 3,
      testDefaultDelayDays: 3,
      testDefaultTime: '08:00',
      lowStockDoses: 3,
      appSyncMinutes: 10,
    });
    expect(timingWarning()).toBeNull();
  });

  it('a changed value changes what the server does', () => {
    process.env.REMINDER_REPEAT_MINUTES = '10';
    expect(backstopAfterMinutes()).toBe(10); // follows the repeat unless set itself
    process.env.BACKSTOP_AFTER_MINUTES = '20';
    expect(backstopAfterMinutes()).toBe(20);

    process.env.TAKEN_CLOSES_BEFORE_NEXT_MINUTES = '30';
    const eight = new Date('2026-01-10T02:00:00.000Z');
    const w = takenWindow({ scheduledAt: eight }, { scheduleTimes: '["08:00","14:00"]', intervalDays: 1 }, null);
    expect(w.closesAt.toISOString()).toBe('2026-01-10T07:30:00.000Z'); // 13:30

    process.env.TEST_REMINDER_DEFAULT_DELAY_DAYS = '1';
    process.env.TEST_REMINDER_DEFAULT_TIME = '09:30';
    const confirmed = new Date('2026-01-10T09:00:00.000Z');
    expect(testReminderTime({ scheduledDate: null, time: null }, confirmed).toISOString()).toBe('2026-01-11T03:30:00.000Z');

    process.env.TEST_REMINDER_DAYS = '5';
    expect(testCaregiverAlertAfterMs()).toBe(4 * 24 * 60 * 60_000);
  });

  it('out-of-range or junk values fall back to the default', () => {
    process.env.REMINDER_RINGS = '0';
    process.env.REMINDER_REPEAT_MINUTES = 'abc';
    process.env.TEST_REMINDER_DEFAULT_TIME = '25:00';
    const t = reminderTiming();
    expect([t.rings, t.repeatMinutes, t.testDefaultTime]).toEqual([4, 15, '08:00']);
  });

  it('warns when the family would be told before the last ring has finished', () => {
    process.env.REMINDER_REPEAT_MINUTES = '20';
    process.env.DOSE_MISSED_GRACE_MINUTES = '50'; // last ring ends at 3 x 20 + 2 = 62
    expect(timingWarning()).toContain('should be more than 62');
  });

  // Round 14 (owner, 2026-11-10): a user may set ring gap, Later delay, rings and family-alert time.
  it("a user's own values replace the .env ones; empty ones keep the default", () => {
    const none = effectiveTiming(null);
    expect([none.repeatMinutes, none.laterMinutes, none.rings, none.missedGraceMinutes]).toEqual([15, 15, 4, 50]);

    const own = effectiveTiming({ reminderRepeatMinutes: 10, reminderLaterMinutes: null, reminderRings: 3, familyAlertMinutes: 40 });
    expect(own).toMatchObject({ repeatMinutes: 10, laterMinutes: 10, rings: 3, missedGraceMinutes: 40, backstopAfterMinutes: 10 });
    expect(lastRingEndsMinutes(own)).toBe(22);

    process.env.REMINDER_LATER_MINUTES = '20';
    expect(effectiveTiming({ reminderLaterMinutes: 30 }).laterMinutes).toBe(30);
    expect(effectiveTiming({}).laterMinutes).toBe(20);
  });
});
