import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../domain/health_models.dart';

final dueHealthRemindersProvider = StreamProvider<List<HealthReminderModel>>((ref) {
  return ref.watch(healthReminderRepositoryProvider).watchDue();
});

final upcomingHealthRemindersProvider = StreamProvider<List<HealthReminderModel>>((ref) {
  return ref.watch(healthReminderRepositoryProvider).watchUpcoming();
});

final allHealthRemindersProvider = StreamProvider<List<HealthReminderModel>>((ref) {
  return ref.watch(healthReminderRepositoryProvider).watchAll();
});

final refreshHealthRemindersProvider = Provider<Future<void> Function()>((ref) {
  final repo = ref.watch(healthReminderRepositoryProvider);
  return () async {
    await repo.refreshFromServer();
  };
});

final completeHealthReminderProvider = Provider<Future<void> Function(String id)>((ref) {
  final repo = ref.watch(healthReminderRepositoryProvider);
  return (id) => repo.markComplete(id);
});

final healthRecordsProvider = StreamProvider<List<HealthRecordModel>>((ref) {
  return ref.watch(healthRecordRepositoryProvider).watchAll();
});

final createHealthRecordProvider = Provider<
    Future<void> Function({
      required String type,
      required String value,
      String? unit,
      String? notes,
    })>((ref) {
  final repo = ref.watch(healthRecordRepositoryProvider);
  return ({required type, required value, unit, notes}) {
    return repo.create(type: type, value: value, unit: unit, notes: notes);
  };
});

final refreshHealthRecordsProvider = Provider<Future<void> Function()>((ref) {
  final repo = ref.watch(healthRecordRepositoryProvider);
  return () => repo.refreshFromServer();
});

/// Published AI health suggestions for the current user.
///
/// Unlike reminders/records above, this is a plain network fetch with no
/// Drift caching or outbox: it's read-only, server-authored content with
/// nothing for the app to create or mutate offline, so the extra
/// local-first machinery isn't needed here. `ref.invalidate(
/// mySuggestionsProvider)` (e.g. from pull-to-refresh) re-fetches.
final mySuggestionsProvider = FutureProvider<List<HealthSuggestionModel>>((ref) async {
  return ref.watch(healthApiProvider).getMySuggestions();
});
