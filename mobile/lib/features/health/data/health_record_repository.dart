import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../sync/outbox_constants.dart';
import '../domain/health_models.dart';
import 'health_api.dart';

const _uuid = Uuid();

/// Health records are user-authored, so — unlike reminders — *creating*
/// one must work offline. Follows the exact same local-write-then-outbox
/// shape as `PrescriptionLocalRepository`: a client-generated id, a
/// draft/queued/syncing/synced/failed [syncState], and a `serverId`
/// filled in once the upload is confirmed.
class HealthRecordRepository {
  HealthRecordRepository({required HealthApi api, required AppDatabase database})
      : _api = api,
        _db = database;

  final HealthApi _api;
  final AppDatabase _db;

  Stream<List<HealthRecordModel>> watchAll() {
    final query = _db.select(_db.healthRecordDrafts)
      ..orderBy([(t) => OrderingTerm.desc(t.recordedAt)]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  /// Writes the record locally and queues it for upload — returns
  /// immediately, online or not.
  Future<void> create({
    required String type,
    required String value,
    String? unit,
    String? notes,
    DateTime? recordedAt,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final effectiveRecordedAt = recordedAt ?? now;

    await _db.transaction(() async {
      await _db.into(_db.healthRecordDrafts).insert(
            HealthRecordDraftsCompanion.insert(
              id: id,
              type: type,
              value: value,
              unit: Value(unit),
              notes: Value(notes),
              recordedAt: effectiveRecordedAt,
              status: const Value('queued'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _db.into(_db.outboxEntries).insert(
            OutboxEntriesCompanion.insert(
              id: _uuid.v4(),
              entityType: OutboxEntityType.healthRecordDraft,
              entityLocalId: id,
              operation: OutboxOperation.create,
              payloadJson: jsonEncode({
                'localId': id,
                'type': type,
                'value': value,
                'unit': unit,
                'notes': notes,
                'recordedAt': effectiveRecordedAt.toUtc().toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });
  }

  /// Pulls the server's list and merges in anything not already
  /// represented locally (a record created on another device, say).
  /// Never touches rows still mid-upload (status queued/syncing).
  Future<void> refreshFromServer() async {
    final serverRecords = await _api.getRecords();
    final localRows = await _db.select(_db.healthRecordDrafts).get();
    final knownServerIds = localRows.map((r) => r.serverId).whereType<String>().toSet();

    final now = DateTime.now();
    for (final record in serverRecords) {
      if (knownServerIds.contains(record.id)) continue;
      await _db.into(_db.healthRecordDrafts).insert(
            HealthRecordDraftsCompanion.insert(
              id: record.id,
              type: record.type,
              value: record.value,
              unit: Value(record.unit),
              notes: Value(record.notes),
              recordedAt: record.recordedAt,
              status: const Value('synced'),
              serverId: Value(record.id),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }

  HealthRecordModel _rowToModel(HealthRecordDraft row) {
    return HealthRecordModel(
      id: row.id,
      type: row.type,
      value: row.value,
      unit: row.unit,
      notes: row.notes,
      recordedAt: row.recordedAt,
      syncState: row.status,
    );
  }
}
