import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../domain/medicine_schedule_models.dart';

final todaysMedicineProvider = StreamProvider<List<MedicineDoseModel>>((ref) {
  return ref.watch(medicineScheduleRepositoryProvider).watchToday();
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

/// Marks a dose taken. Always succeeds instantly (local-first) — the
/// repository queues the actual server call; see
/// `MedicineScheduleRepository.markDoseTaken` / `DoseSyncHandler`.
final markDoseTakenProvider = Provider<Future<void> Function(String doseId)>((ref) {
  final repo = ref.watch(medicineScheduleRepositoryProvider);
  return (doseId) => repo.markDoseTaken(doseId);
});
