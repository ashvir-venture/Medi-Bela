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
