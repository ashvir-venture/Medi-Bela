import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../sync/outbox_constants.dart';
import '../../../sync/sync_handler.dart';
import 'prescription_api.dart';

/// Uploads a queued prescription in the background (the user never waits
/// on the screen). Round 18: every page goes straight to Cloudinary, then
/// one call makes the prescription; 3 tries with a growing pause (30 s,
/// 2 min), then the draft shows "failed" and [onFailed] tells the user.
class PrescriptionSyncHandler implements SyncHandler, RetryPolicy {
  PrescriptionSyncHandler({
    required PrescriptionApi api,
    required AppDatabase database,
    Future<void> Function(String draftId)? onFailed,
  })  : _api = api,
        _db = database,
        _onFailed = onFailed;

  final PrescriptionApi _api;
  final AppDatabase _db;
  final Future<void> Function(String draftId)? _onFailed;

  @override
  String get entityType => OutboxEntityType.prescriptionDraft;

  @override
  int get maxRetries => 3;

  @override
  Duration backoff(int retryCount) => Duration(seconds: 30 * (1 << ((retryCount - 1) * 2)));

  @override
  Future<void> sync(OutboxEntry entry) async {
    final payload = jsonDecode(entry.payloadJson) as Map<String, dynamic>;
    final pages = ((payload['pages'] as List<dynamic>?) ?? const []).whereType<String>().toList();
    final single = payload['imageLocalPath'] as String?;
    await _setStatus(entry.entityLocalId, 'syncing');
    final serverId = await _api.uploadPages(
      clientId: payload['clientId'] as String,
      pages: pages.isNotEmpty ? pages : [?single],
      note: payload['note'] as String?,
      previousPrescriptionId: payload['previousPrescriptionId'] as String?,
    );

    await (_db.update(_db.prescriptionDrafts)..where((t) => t.id.equals(entry.entityLocalId))).write(
      PrescriptionDraftsCompanion(
        status: const Value('synced'),
        serverId: Value(serverId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> onGaveUp(OutboxEntry entry) async {
    await _setStatus(entry.entityLocalId, 'failed');
    await _onFailed?.call(entry.entityLocalId);
  }

  Future<void> _setStatus(String id, String status) =>
      (_db.update(_db.prescriptionDrafts)..where((t) => t.id.equals(id)))
          .write(PrescriptionDraftsCompanion(status: Value(status), updatedAt: Value(DateTime.now())));
}
