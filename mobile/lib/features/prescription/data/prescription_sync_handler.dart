import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../sync/outbox_constants.dart';
import '../../../sync/sync_handler.dart';
import 'prescription_api.dart';

class PrescriptionSyncHandler implements SyncHandler {
  PrescriptionSyncHandler({
    required PrescriptionApi api,
    required AppDatabase database,
  })  : _api = api,
        _db = database;

  final PrescriptionApi _api;
  final AppDatabase _db;

  @override
  String get entityType => OutboxEntityType.prescriptionDraft;

  @override
  Future<void> sync(OutboxEntry entry) async {
    final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;

    final serverId = await _api.uploadDraft(
      clientId: payload['clientId'] as String,
      note: payload['note'] as String?,
      imageLocalPath: payload['imageLocalPath'] as String?,
    );

    await (_db.update(_db.prescriptionDrafts)
          ..where((t) => t.id.equals(entry.entityLocalId)))
        .write(
      PrescriptionDraftsCompanion(
        status: const Value('synced'),
        serverId: Value(serverId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
