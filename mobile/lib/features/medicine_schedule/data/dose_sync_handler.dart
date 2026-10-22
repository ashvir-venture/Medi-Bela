import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../sync/outbox_constants.dart';
import '../../../sync/sync_handler.dart';
import 'medicine_schedule_api.dart';

class DoseSyncHandler implements SyncHandler {
  DoseSyncHandler({
    required MedicineScheduleApi api,
    required AppDatabase database,
  })  : _api = api,
        _db = database;

  final MedicineScheduleApi _api;
  final AppDatabase _db;

  @override
  String get entityType => OutboxEntityType.doseTaken;

  @override
  Future<void> sync(OutboxEntry entry) async {
    final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
    final doseId = payload['doseId'] as String;
    final takenAt = DateTime.parse(payload['takenAt'] as String);

    // The backend's markDoseTaken is itself idempotent (see
    // MedicineScheduleService.markDoseTaken), so a retried outbox entry
    // — e.g. the app was killed after this succeeded but before the
    // local row got updated below — can never double-log or error.
    final serverDose = await _api.markDoseTaken(doseId, takenAt: takenAt);

    await (_db.update(_db.cachedMedicineDoses)..where((t) => t.id.equals(doseId))).write(
      CachedMedicineDosesCompanion(
        doseStatus: Value(serverDose.status),
        takenAt: Value(serverDose.takenAt),
        syncState: const Value('synced'),
        cachedAt: Value(DateTime.now()),
      ),
    );
  }
}
