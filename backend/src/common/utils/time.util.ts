/**
 * The app serves one timezone (Bangladesh, UTC+6, no DST) — the mobile app
 * hard-codes Asia/Dhaka for its local notifications too. Doses are stored
 * as absolute instants (UTC); "08:00" and "today" must be interpreted in the
 * APP timezone, never the server's. Using `Date#setHours` made both depend
 * on whatever TZ the server process happened to run in (UTC on most hosts),
 * which shifted every dose by six hours.
 *
 * Override with APP_UTC_OFFSET_MINUTES if this ever serves another zone.
 */
const DEFAULT_OFFSET_MINUTES = 360;
const MINUTE_MS = 60_000;
const DAY_MS = 24 * 60 * MINUTE_MS;

export function appUtcOffsetMinutes(): number {
  const raw = process.env.APP_UTC_OFFSET_MINUTES;
  const parsed = raw === undefined || raw === '' ? NaN : Number(raw);
  return Number.isFinite(parsed) ? parsed : DEFAULT_OFFSET_MINUTES;
}

/** Instant of 00:00 (app timezone) on the app-timezone calendar day containing `ref`. */
export function startOfAppDay(ref: Date, offsetMinutes = appUtcOffsetMinutes()): Date {
  const shifted = ref.getTime() + offsetMinutes * MINUTE_MS;
  const localMidnightAsUtc = Math.floor(shifted / DAY_MS) * DAY_MS;
  return new Date(localMidnightAsUtc - offsetMinutes * MINUTE_MS);
}

export function appDayBounds(ref: Date, offsetMinutes = appUtcOffsetMinutes()) {
  const start = startOfAppDay(ref, offsetMinutes);
  return { start, end: new Date(start.getTime() + DAY_MS) };
}

export function addAppDays(dayStart: Date, days: number): Date {
  return new Date(dayStart.getTime() + days * DAY_MS);
}

/** `hhmm` ("HH:mm") on the app-timezone day that starts at `dayStart`. */
export function atAppTime(dayStart: Date, hhmm: string): Date {
  const [h, m] = hhmm.split(':').map(Number);
  return new Date(dayStart.getTime() + (h * 60 + m) * MINUTE_MS);
}
