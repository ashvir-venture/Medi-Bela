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
 * as DUE before the missed-sweep converts it to MISSED. Configurable via
 * env so ops can tune it without a code change; defaults to a generous
 * 2 hours so a dose isn't marked missed just because the sync/notification
 * fired a few minutes late.
 */
export function missedGraceMinutes(): number {
  const raw = process.env.DOSE_MISSED_GRACE_MINUTES;
  const parsed = raw ? Number(raw) : NaN;
  return Number.isFinite(parsed) && parsed > 0 ? parsed : 120;
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
