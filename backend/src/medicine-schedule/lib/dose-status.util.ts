import { DoseStatus } from '@prisma/client';

/**
 * `DoseStatus` (PENDING/TAKEN/MISSED/SKIPPED) is what's stored — it only
 * changes on an explicit action (user marks TAKEN, or the missed-sweep
 * below marks MISSED). UPCOMING vs DUE is *never* stored: it's purely a
 * function of "is a still-PENDING dose's scheduled time in the past or
 * future right now", recomputed on every read. Keeping it unstored means
 * there's nothing to keep in sync and no invented state to get stale.
 */
export type DoseDisplayStatus = 'UPCOMING' | 'DUE' | 'TAKEN' | 'MISSED' | 'SKIPPED';

/**
 * How long after the scheduled time a still-untaken dose keeps showing
 * as DUE before the missed-sweep converts it to MISSED (which is also when
 * the family is alerted). Configurable via env so ops can tune it without a
 * code change. Defaults to 62 minutes: the app reminds at the scheduled time,
 * again at +30 and, after two "Later" snoozes, at +60 with a 2-minute ring,
 * so the family is never alerted while a snooze is still running.
 */
export const DEFAULT_MISSED_GRACE_MINUTES = 62;

export function missedGraceMinutes(): number {
  const raw = process.env.DOSE_MISSED_GRACE_MINUTES;
  const parsed = raw ? Number(raw) : NaN;
  return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_MISSED_GRACE_MINUTES;
}

export function missedCutoff(reference: Date = new Date()): Date {
  const cutoff = new Date(reference);
  cutoff.setMinutes(cutoff.getMinutes() - missedGraceMinutes());
  return cutoff;
}

export function computeDisplayStatus(
  status: DoseStatus,
  scheduledAt: Date,
  now: Date = new Date(),
): DoseDisplayStatus {
  if (status !== DoseStatus.PENDING) {
    // TAKEN, MISSED, SKIPPED are all explicit/terminal — shown as-is.
    return status;
  }
  return scheduledAt.getTime() <= now.getTime() ? 'DUE' : 'UPCOMING';
}

/**
 * Status as it should be *shown* right now, without writing anything: a
 * PENDING dose already past the missed cutoff is MISSED even if the
 * background sweep hasn't flipped the stored row yet. Used by read-only
 * views of OTHER people's doses (family status), which must never mutate.
 */
export function effectiveStatus(
  status: DoseStatus,
  scheduledAt: Date,
  now: Date = new Date(),
): DoseStatus {
  if (status === DoseStatus.PENDING && scheduledAt.getTime() < missedCutoff(now).getTime()) {
    return DoseStatus.MISSED;
  }
  return status;
}
