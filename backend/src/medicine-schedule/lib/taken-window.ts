import { addAppDays, atAppTime, startOfAppDay } from '../../common/utils/time.util';
import { parseScheduleTimes } from '../../prescriptions/lib/routine-generation.service';
import { reminderTiming } from '../../common/config/reminder-timing';

/** A dose can be marked taken until this long before the medicine's next dose (TAKEN_CLOSES_BEFORE_NEXT_MINUTES). */
export function takenClosesBeforeNextMs(): number {
  return reminderTiming().takenClosesBeforeNextMinutes * 60_000;
}
/** Phone clocks run a little early or late: a tap this close before the time counts. */
export const TAKEN_CLOCK_TOLERANCE_MS = 2 * 60_000;

/**
 * When a dose can be marked taken (owner, 2026-10-31): from its own time
 * (never an upcoming dose) until 1 hour before the same medicine's next dose
 * — an 08:00 dose with a 14:00 one after it closes at 13:00. Without a
 * stored next dose (the course ends, or the rolling job hasn't reached it)
 * the next one is worked out from the routine's times and every N days.
 */
export function takenWindow(
  dose: { scheduledAt: Date },
  routine: { scheduleTimes: string | null; intervalDays: number },
  nextScheduledAt: Date | null,
): { opensAt: Date; closesAt: Date } {
  const next = nextScheduledAt ?? nextFromSchedule(dose.scheduledAt, routine);
  return { opensAt: dose.scheduledAt, closesAt: new Date(next.getTime() - takenClosesBeforeNextMs()) };
}

function nextFromSchedule(at: Date, routine: { scheduleTimes: string | null; intervalDays: number }): Date {
  const day = startOfAppDay(at);
  const later = parseScheduleTimes(routine.scheduleTimes)
    .map((t) => atAppTime(day, t))
    .filter((t) => t > at)
    .sort((a, b) => a.getTime() - b.getTime());
  if (later.length) return later[0];
  const times = parseScheduleTimes(routine.scheduleTimes).sort();
  const nextDay = addAppDays(day, Math.max(1, routine.intervalDays));
  return times.length ? atAppTime(nextDay, times[0]) : addAppDays(at, Math.max(1, routine.intervalDays));
}
