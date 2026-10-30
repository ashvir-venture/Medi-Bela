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
  ///
  /// [previousPrescriptionId] (server id of a REJECTED prescription) marks a
  /// re-upload. It only travels in the outbox payload, so the Drift schema
  /// is unchanged.
  Future<String> createAndQueue({
    String? note,
    String? imageLocalPath,
    String? previousPrescriptionId,
  }) async {
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
                if (previousPrescriptionId != null)
                  'previousPrescriptionId': previousPrescriptionId,
              }),
              createdAt: now,
            ),
          );
    });

    return id;
  }

  /// Pulls the latest status (PENDING/AWAITING_CONFIRMATION/REJECTED/...) for
  /// every draft that has already synced (has a [PrescriptionDraft.serverId]),
  /// so the user sees pharmacist decisions without having to re-open the app,
  /// and adds my own server prescriptions this phone doesn't have (after a
  /// reinstall, a new phone or a sign-out, which clear the local database).
  /// Prescriptions my caregiver uploaded stay server-only (listed apart).
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
    final local = await _db.select(_db.prescriptionDrafts).get();

    for (final draft in local.where((d) => d.serverId != null)) {
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

    // An upload still on its way has no serverId yet, but the server may
    // already have it: adding server rows now could list it twice. The next
    // refresh, after the upload finishes, adds anything missing.
    if (local.any((d) => d.serverId == null && d.status != 'failed')) return;

    final known = local.map((d) => d.serverId).whereType<String>().toSet();
    final now = DateTime.now();
    for (final p in history) {
      if (p.uploadedByCaregiver || known.contains(p.id)) continue;
      await _db.into(_db.prescriptionDrafts).insert(
            PrescriptionDraftsCompanion.insert(
              id: p.id,
              status: const Value('synced'),
              serverId: Value(p.id),
              serverStatus: Value(p.status),
              rejectionReason: Value(p.rejectionReason),
              createdAt: p.createdAt.toLocal(),
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
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
