import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../sync/outbox_constants.dart';
import '../domain/prescription_draft_model.dart';
import '../domain/prescription_models.dart';
import 'prescription_api.dart';

const _uuid = Uuid();

/// Implements the "user marks an action offline → saved locally → queued
/// → synced later" flow from the product brief, applied to prescription
/// entries (the Home screen's "Upload Prescription / Direct entry" quick
/// action).
///
/// Writing is always local-first and always succeeds instantly, online or
/// not — [SyncService] is solely responsible for getting the data to the
/// server whenever that becomes possible.
class PrescriptionLocalRepository {
  PrescriptionLocalRepository({
    required AppDatabase database,
    required PrescriptionApi api,
  })  : _db = database,
        _api = api;

  final AppDatabase _db;
  final PrescriptionApi _api;

  Stream<List<PrescriptionDraftModel>> watchDrafts() {
    final query = _db.select(_db.prescriptionDrafts)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  Future<List<PrescriptionDraftModel>> getDrafts() async {
    final query = _db.select(_db.prescriptionDrafts)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final rows = await query.get();
    return rows.map(_rowToModel).toList();
  }

  /// Saves a new draft and queues it for upload. Returns the local id
  /// immediately — the caller never waits on the network.
  Future<String> createAndQueue({String? note, String? imageLocalPath}) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.transaction(() async {
      await _db.into(_db.prescriptionDrafts).insert(
            PrescriptionDraftsCompanion.insert(
              id: id,
              imageLocalPath: Value(imageLocalPath),
              note: Value(note),
              status: const Value('queued'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _db.into(_db.outboxEntries).insert(
            OutboxEntriesCompanion.insert(
              id: _uuid.v4(),
              entityType: OutboxEntityType.prescriptionDraft,
              entityLocalId: id,
              operation: OutboxOperation.create,
              payloadJson: jsonEncode({
                'clientId': id,
                'note': note,
                'imageLocalPath': imageLocalPath,
              }),
              createdAt: now,
            ),
          );
    });

    return id;
  }

  /// Pulls the latest status (PENDING/COMPLETED/REJECTED) for every draft
  /// that has already synced (has a [PrescriptionDraft.serverId]), so the
  /// user sees pharmacist decisions without having to re-open the app.
  /// Safe to call opportunistically (e.g. pull-to-refresh, app resume);
  /// silently no-ops if the network call fails, since the previously
  /// cached status remains valid to show.
  Future<void> refreshStatuses() async {
    List<PrescriptionSummaryModel> history;
    try {
      history = await _api.getHistory();
    } catch (_) {
      return;
    }

    final byServerId = {for (final p in history) p.id: p};

    final drafts = await (_db.select(_db.prescriptionDrafts)
          ..where((t) => t.serverId.isNotNull()))
        .get();

    for (final draft in drafts) {
      final match = byServerId[draft.serverId];
      if (match == null) continue;
      await (_db.update(_db.prescriptionDrafts)..where((t) => t.id.equals(draft.id)))
          .write(
        PrescriptionDraftsCompanion(
          serverStatus: Value(match.status),
          rejectionReason: Value(match.rejectionReason),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  PrescriptionDraftModel _rowToModel(PrescriptionDraft row) {
    return PrescriptionDraftModel(
      id: row.id,
      imageLocalPath: row.imageLocalPath,
      note: row.note,
      status: row.status,
      serverId: row.serverId,
      serverStatus: row.serverStatus,
      rejectionReason: row.rejectionReason,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
