import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../sync/outbox_constants.dart';
import '../../../sync/sync_handler.dart';
import 'health_api.dart';

/// Uploads a locally-created health record. Unlike dose/reminder
/// completion, record creation has no natural server-side idempotency
/// key (there's no equivalent of `clientUploadId` on `HealthRecord` in
/// this phase — see the final summary's assumptions). A retried entry
/// after a genuine failure (not "succeeded but we didn't hear back") is
/// idempotent: `clientId` (the local draft uuid) lets the backend return the
/// existing record when a sync is retried.
class HealthRecordSyncHandler implements SyncHandler {
  HealthRecordSyncHandler({required HealthApi api, required AppDatabase database})
      : _api = api,
        _db = database;

  final HealthApi _api;
  final AppDatabase _db;

  @override
  String get entityType => OutboxEntityType.healthRecordDraft;

  @override
  Future<void> sync(OutboxEntry entry) async {
    final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
    final localId = payload['localId'] as String;

    final serverRecord = await _api.createRecord(
      type: payload['type'] as String,
      value: payload['value'] as String,
      unit: payload['unit'] as String?,
      notes: payload['notes'] as String?,
      recordedAt: DateTime.parse(payload['recordedAt'] as String),
      // The draft's uuid doubles as the idempotency key: a retried sync
      // returns the same server record instead of creating a duplicate.
      clientId: localId,
    );

    await (_db.update(_db.healthRecordDrafts)..where((t) => t.id.equals(localId))).write(
      HealthRecordDraftsCompanion(
        status: const Value('synced'),
        serverId: Value(serverRecord.id),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
