import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../domain/medicine_schedule_models.dart';

final todaysMedicineProvider = StreamProvider<List<MedicineDoseModel>>((ref) {
  return ref.watch(medicineScheduleRepositoryProvider).watchToday();
});

/// Round 14: the last 7 days (the week strip on Today): from the server
/// when online, else what this phone has cached (today at least).
final lastWeekDosesProvider = FutureProvider.autoDispose<List<MedicineDoseModel>>((ref) async {
  final today = DateTime.now();
  final end = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
  final start = end.subtract(const Duration(days: 7));
  try {
    return await ref.watch(medicineScheduleApiProvider).getHistory(start, end);
  } catch (_) {
    return ref.watch(medicineScheduleRepositoryProvider).watchLastWeek().first;
  }
});

final activeRoutinesProvider = StreamProvider<List<MedicineRoutineModel>>((ref) {
  return ref.watch(medicineScheduleRepositoryProvider).watchActiveRoutines();
});

/// Triggers a server refresh; the two stream providers above update
/// automatically once the local cache is rewritten.
final refreshMedicineScheduleProvider = Provider<Future<void> Function()>((ref) {
  final repo = ref.watch(medicineScheduleRepositoryProvider);
  return () async {
    await repo.refreshFromServer();
  };
});

/// Marks a dose taken, instantly (local-first) — the repository queues the
/// actual server call; see `MedicineScheduleRepository.markDoseTaken` /
/// `DoseSyncHandler`. False outside the dose's taken window.
final markDoseTakenProvider = Provider<Future<bool> Function(String doseId)>((ref) {
  final repo = ref.watch(medicineScheduleRepositoryProvider);
  return (doseId) => repo.markDoseTaken(doseId);
});


/// Round 18 (client point 7): the doses of one day for My medicine's day
/// arrows. Today and later days come from the phone's cache (offline);
/// an earlier day from the server's history, else whatever is cached.
final dayDosesProvider = StreamProvider.autoDispose.family<List<MedicineDoseModel>, DateTime>((ref, day) async* {
  final today = DateTime.now();
  final start = DateTime(day.year, day.month, day.day);
  final repo = ref.watch(medicineScheduleRepositoryProvider);
  if (!start.isBefore(DateTime(today.year, today.month, today.day))) {
    yield* repo.watchDay(start);
    return;
  }
  try {
    final rows = await ref.watch(medicineScheduleApiProvider).getHistory(start, start.add(const Duration(days: 1)));
    rows.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    yield rows;
  } catch (_) {
    yield* repo.watchDay(start);
  }
});

/// Round 18 (client point 6): the last 30 days, for "taken on x of y days"
/// per medicine. Online; empty when it can't load.
final last30DaysDosesProvider = FutureProvider.autoDispose<List<MedicineDoseModel>>((ref) async {
  final today = DateTime.now();
  final end = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
  try {
    return await ref.watch(medicineScheduleApiProvider).getHistory(end.subtract(const Duration(days: 30)), end);
  } catch (_) {
    return const <MedicineDoseModel>[];
  }
});

/// Days of the last 30 on which every dose of [routineId] was taken, and
/// the days it had any dose ("taken on 26 of 30 days").
(int, int) takenDays(String routineId, Iterable<MedicineDoseModel> doses) {
  final byDay = <DateTime, List<MedicineDoseModel>>{};
  for (final d in doses.where((d) => d.routineId == routineId)) {
    final k = DateTime(d.scheduledAt.year, d.scheduledAt.month, d.scheduledAt.day);
    (byDay[k] ??= []).add(d);
  }
  final now = DateTime.now();
  // Days still running (a dose not yet due) don't count either way.
  final decided = byDay.entries.where((e) => e.value.every((d) => d.isTaken || d.scheduledAt.isBefore(now)));
  final all = decided.where((e) => e.value.every((d) => d.isTaken)).length;
  return (all, decided.length);
}
