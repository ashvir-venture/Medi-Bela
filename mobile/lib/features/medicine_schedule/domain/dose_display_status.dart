import '../../../notifications/reminder_timing.dart';
import 'medicine_schedule_models.dart';

/// UPCOMING/DUE are never stored (mirrors the backend — see its
/// `dose-status.util.ts`): they're purely "is a still-PENDING dose's
/// scheduled time in the past or future right now", recomputed on every
/// build so the label updates live even between syncs.
enum DoseDisplayStatus { upcoming, due, taken, missed, skipped }

DoseDisplayStatus computeDoseDisplayStatus(MedicineDoseModel dose, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  switch (dose.status) {
    case 'TAKEN':
      return DoseDisplayStatus.taken;
    case 'MISSED':
      return DoseDisplayStatus.missed;
    case 'SKIPPED':
      return DoseDisplayStatus.skipped;
    default:
      return dose.scheduledAt.isAfter(reference) ? DoseDisplayStatus.upcoming : DoseDisplayStatus.due;
  }
}

/// Round 14 (owner, 2026-11-10): how a past dose went. On time = taken before
/// the family-alert time (the user's own or the server's, [ReminderTiming]
/// missedGraceMinutes); Late = taken after it; Missed = never taken. Null
/// while it is still open (upcoming or due and not missed).
enum DoseOutcome { onTime, late, missed }

DoseOutcome? doseOutcome(MedicineDoseModel dose, {int? graceMinutes}) {
  switch (dose.status) {
    case 'TAKEN':
      final takenAt = dose.takenAt;
      if (takenAt == null) return DoseOutcome.onTime;
      final grace = Duration(minutes: graceMinutes ?? ReminderTiming.current.missedGraceMinutes);
      return takenAt.isAfter(dose.scheduledAt.add(grace)) ? DoseOutcome.late : DoseOutcome.onTime;
    case 'MISSED':
    case 'SKIPPED':
      return DoseOutcome.missed;
    default:
      return null;
  }
}
