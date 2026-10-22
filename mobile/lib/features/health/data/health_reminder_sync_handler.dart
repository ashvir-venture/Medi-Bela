import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../sync/outbox_constants.dart';
import '../../../sync/sync_handler.dart';
import 'health_api.dart';

class HealthReminderSyncHandler implements SyncHandler {
  HealthReminderSyncHandler({required HealthApi api, required AppDatabase database})
      : _api = api,
        _db = database;

  final HealthApi _api;
  final AppDatabase _db;

  @override
  String get entityType => OutboxEntityType.healthReminderComplete;

  @override
  Future<void> sync(OutboxEntry entry) async {
    final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
    final reminderId = payload['reminderId'] as String;
    final completedAt = DateTime.parse(payload['completedAt'] as String);

    // Backend's markComplete is idempotent (see HealthRemindersService),
    // so a retried entry can never error out or double-complete.
    final serverReminder = await _api.completeReminder(reminderId, completedAt: completedAt);

    await (_db.update(_db.cachedHealthReminders)..where((t) => t.id.equals(reminderId))).write(
      CachedHealthRemindersCompanion(
        status: Value(serverReminder.status),
        completedAt: Value(serverReminder.completedAt),
        syncState: const Value('synced'),
        cachedAt: Value(DateTime.now()),
      ),
    );
  }
}
