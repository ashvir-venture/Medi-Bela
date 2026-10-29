import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/result.dart';
import '../../../notifications/notification_scheduler.dart';
import '../../../sync/outbox_constants.dart';
import '../domain/medicine_schedule_models.dart';
import 'medicine_schedule_api.dart';

const _uuid = Uuid();

/// Local-first access to medicine routines/doses, including the one
/// piece that *isn't* purely read-only: marking a dose taken.
///
/// Routines and individual dose *schedules* are only ever produced
/// server-side (by admin prescription completion), so there's nothing to
/// queue for those. Marking a dose TAKEN is different — that's a user
/// action that must work offline, per the product brief — so it follows
/// the same local-write-then-outbox pattern as
/// `PrescriptionLocalRepository.createAndQueue`.
///
/// [watchToday] / [watchActiveRoutines] serve instantly from the Drift
/// cache; call [refreshFromServer] to pull the latest (pull-to-refresh,
/// app resume, or opportunistically after [SyncService] confirms
/// connectivity).
class MedicineScheduleRepository {
  MedicineScheduleRepository({
    required MedicineScheduleApi api,
    required AppDatabase database,
    required NotificationScheduler notificationScheduler,
  })  : _api = api,
        _db = database,
        _notifications = notificationScheduler;

  final MedicineScheduleApi _api;
  final AppDatabase _db;
  final NotificationScheduler _notifications;

  Stream<List<MedicineDoseModel>> watchToday() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));

    final query = _db.select(_db.cachedMedicineDoses)
      ..where((t) => t.scheduledAt.isBiggerOrEqualValue(start) & t.scheduledAt.isSmallerThanValue(end))
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]);
    return query.watch().map((rows) => rows.map(_doseRowToModel).toList());
  }

  Stream<List<MedicineRoutineModel>> watchActiveRoutines() {
    final query = _db.select(_db.cachedMedicineRoutines)
      ..where((t) => t.active.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.startDate)]);
    return query.watch().map((rows) => rows.map(_routineRowToModel).toList());
  }

  /// Marks [doseId] TAKEN immediately in the local cache (so the UI
  /// updates instantly, online or not), then queues the corresponding
  /// server call. [SyncService] drains the queue whenever connectivity
  /// allows — see `DoseSyncHandler`.
  ///
  /// Deliberately does nothing if the dose is already TAKEN or SKIPPED
  /// locally (mirrors the backend's own idempotency/terminal-state
  /// rules) so a double-tap can't queue two outbox entries.
  Future<void> markDoseTaken(String doseId) async {
    final existing = await (_db.select(_db.cachedMedicineDoses)..where((t) => t.id.equals(doseId)))
        .getSingleOrNull();
    if (existing == null) return;
    if (existing.doseStatus == 'TAKEN' || existing.doseStatus == 'SKIPPED') return;

    final now = DateTime.now();

    await _db.transaction(() async {
      await (_db.update(_db.cachedMedicineDoses)..where((t) => t.id.equals(doseId))).write(
        CachedMedicineDosesCompanion(
          doseStatus: const Value('TAKEN'),
          takenAt: Value(now),
          syncState: const Value('pending'),
        ),
      );

      await _db.into(_db.outboxEntries).insert(
            OutboxEntriesCompanion.insert(
              id: _uuid.v4(),
              entityType: OutboxEntityType.doseTaken,
              entityLocalId: doseId,
              operation: OutboxOperation.update,
              payloadJson: jsonEncode({
                'doseId': doseId,
                'takenAt': now.toUtc().toIso8601String(),
              }),
              createdAt: now,
            ),
          );
    });

    // A taken dose should never keep reminding — cancel right away
    // rather than waiting for the next reconcile pass.
    await _notifications.cancelForDose(doseId);
  }

  /// Re-derives on-device reminders from the local cache alone — no network.
  /// Run at app start/resume so reminders exist even if the user never opens
  /// the medicine screen and even while offline.
  Future<void> reconcileLocalNotifications() async {
    final cached = await _db.select(_db.cachedMedicineDoses).get();
    await _notifications.reconcile(cached.map(_doseRowToModel).toList());
  }

  Future<Result<void>> refreshFromServer() async {
    try {
      final routines = await _api.getActiveRoutines();
      final todayDoses = await _api.getToday();
      final upcomingDoses = await _api.getUpcoming(days: 7);
      final allDoses = _dedupeById([...todayDoses, ...upcomingDoses]);

      await _replaceCache(routines, allDoses);

      // Reconcile against the merged *local* view (not the raw server
      // response) so a dose the user just marked taken offline — still
      // showing syncState=pending, not yet reflected server-side — isn't
      // treated as "still needs a reminder" and rescheduled.
      final cachedDoses = await _db.select(_db.cachedMedicineDoses).get();
      await _notifications.reconcile(cachedDoses.map(_doseRowToModel).toList());

      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  List<MedicineDoseModel> _dedupeById(List<MedicineDoseModel> doses) {
    final byId = <String, MedicineDoseModel>{};
    for (final d in doses) {
      byId[d.id] = d;
    }
    return byId.values.toList();
  }

  Future<void> _replaceCache(
    List<MedicineRoutineModel> routines,
    List<MedicineDoseModel> doses,
  ) async {
    final now = DateTime.now();
    final keepIds = doses.map((d) => d.id).toList();
    await _db.transaction(() async {
      // A routine edited or removed (by the patient or their caregiver) has
      // new dose ids on the server; old cached doses must not keep ringing.
      await (_db.delete(_db.cachedMedicineDoses)
            ..where((t) => t.id.isNotIn(keepIds) & t.syncState.equals('synced')))
          .go();
      await _db.delete(_db.cachedMedicineRoutines).go();
      for (final r in routines) {
        await _db.into(_db.cachedMedicineRoutines).insert(
              CachedMedicineRoutinesCompanion.insert(
                id: r.id,
                medicineName: r.medicineName,
                dosage: r.dosage,
                frequency: r.frequency,
                startDate: r.startDate,
                endDate: Value(r.endDate),
                active: Value(r.active),
                cachedAt: now,
              ),
            );
      }

      for (final d in doses) {
        final existing =
            await (_db.select(_db.cachedMedicineDoses)..where((t) => t.id.equals(d.id)))
                .getSingleOrNull();

        // A dose the user marked taken locally, not yet confirmed by the
        // server, must not be clobbered back to PENDING by a refresh
        // that raced ahead of the sync — the outbox/DoseSyncHandler is
        // the only thing allowed to clear syncState=pending/syncing.
        final hasUnsyncedLocalChange =
            existing != null && (existing.syncState == 'pending' || existing.syncState == 'syncing');
        if (hasUnsyncedLocalChange) continue;

        await _db.into(_db.cachedMedicineDoses).insertOnConflictUpdate(
              CachedMedicineDosesCompanion.insert(
                id: d.id,
                routineId: d.routineId,
                medicineName: d.medicineName,
                dosage: d.dosage,
                scheduledAt: d.scheduledAt,
                doseStatus: d.status,
                takenAt: Value(d.takenAt),
                syncState: const Value('synced'),
                cachedAt: now,
              ),
            );
      }
    });
  }

  MedicineDoseModel _doseRowToModel(CachedMedicineDose row) {
    return MedicineDoseModel(
      id: row.id,
      routineId: row.routineId,
      medicineName: row.medicineName,
      dosage: row.dosage,
      scheduledAt: row.scheduledAt,
      status: row.doseStatus,
      takenAt: row.takenAt,
      syncState: row.syncState,
    );
  }

  MedicineRoutineModel _routineRowToModel(CachedMedicineRoutine row) {
    return MedicineRoutineModel(
      id: row.id,
      medicineName: row.medicineName,
      dosage: row.dosage,
      frequency: row.frequency,
      startDate: row.startDate,
      endDate: row.endDate,
      active: row.active,
    );
  }
}
