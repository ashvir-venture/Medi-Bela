import { missedGraceMinutes } from '../../medicine-schedule/lib/dose-status.util';

/**
 * Every reminder timing in one place, read from .env each time (owner,
 * 2026-10-31: "changing it there changes that thing"). The server uses them
 * directly; the app reads them from GET /app-config on every refresh and
 * reschedules its reminders when they change. A missing or out-of-range
 * value falls back to the default.
 */
export interface ReminderTiming {
  /** Minutes between medicine rings, and what Later waits (REMINDER_REPEAT_MINUTES, 15). */
  repeatMinutes: number;
  /** Rings per dose time before the family is told (REMINDER_RINGS, 4). */
  rings: number;
  /** How long one ring sounds (REMINDER_RING_MINUTES, 2). */
  ringMinutes: number;
  /** Untaken this long after its time: MISSED, family alerted (DOSE_MISSED_GRACE_MINUTES, 50). */
  missedGraceMinutes: number;
  /** Server backstop push to the patient (BACKSTOP_AFTER_MINUTES, = repeatMinutes). */
  backstopAfterMinutes: number;
  /** "Taken" closes this long before the medicine's next dose (TAKEN_CLOSES_BEFORE_NEXT_MINUTES, 60). */
  takenClosesBeforeNextMinutes: number;
  /** A test reminder rings this many days (TEST_REMINDER_DAYS, 3); the caregiver is told on the last. */
  testReminderDays: number;
  /** A test without a date rings this many days after confirmation (TEST_REMINDER_DEFAULT_DELAY_DAYS, 3). */
  testDefaultDelayDays: number;
  /** A test without a time rings at (TEST_REMINDER_DEFAULT_TIME, 08:00). */
  testDefaultTime: string;
  /** Medicine box "running low" at this many doses left (MEDICINE_BOX_LOW_DOSES, 3). */
  lowStockDoses: number;
  /** The app asks the server again this often while open (APP_SYNC_MINUTES, 10). */
  appSyncMinutes: number;
}

function int(name: string, fallback: number, min: number, max: number): number {
  const raw = process.env[name];
  const n = raw === undefined || raw === '' ? NaN : Number(raw);
  return Number.isInteger(n) && n >= min && n <= max ? n : fallback;
}

function hhmm(name: string, fallback: string): string {
  const raw = process.env[name]?.trim();
  return raw && /^([01]\d|2[0-3]):[0-5]\d$/.test(raw) ? raw : fallback;
}

export function reminderTiming(): ReminderTiming {
  const repeatMinutes = int('REMINDER_REPEAT_MINUTES', 15, 1, 180);
  return {
    repeatMinutes,
    rings: int('REMINDER_RINGS', 4, 1, 10),
    ringMinutes: int('REMINDER_RING_MINUTES', 2, 1, 10),
    missedGraceMinutes: missedGraceMinutes(),
    backstopAfterMinutes: int('BACKSTOP_AFTER_MINUTES', repeatMinutes, 1, 720),
    takenClosesBeforeNextMinutes: int('TAKEN_CLOSES_BEFORE_NEXT_MINUTES', 60, 0, 720),
    testReminderDays: int('TEST_REMINDER_DAYS', 3, 1, 14),
    testDefaultDelayDays: int('TEST_REMINDER_DEFAULT_DELAY_DAYS', 3, 0, 60),
    testDefaultTime: hhmm('TEST_REMINDER_DEFAULT_TIME', '08:00'),
    lowStockDoses: int('MEDICINE_BOX_LOW_DOSES', 3, 0, 100),
    appSyncMinutes: int('APP_SYNC_MINUTES', 10, 1, 1440),
  };
}

/**
 * The family alert must come after the last ring has finished:
 * (rings - 1) x repeat + ring. Returns a warning when it doesn't.
 */
export function timingWarning(t: ReminderTiming = reminderTiming()): string | null {
  const lastRingEnds = (t.rings - 1) * t.repeatMinutes + t.ringMinutes;
  return t.missedGraceMinutes <= lastRingEnds
    ? `DOSE_MISSED_GRACE_MINUTES (${t.missedGraceMinutes}) should be more than ${lastRingEnds}: ` +
        `the family would be alerted while a reminder can still ring`
    : null;
}
