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
