import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/result.dart';
import '../../../notifications/notification_scheduler.dart';
import '../../../sync/outbox_constants.dart';
import '../domain/health_models.dart';
import 'health_api.dart';

const _uuid = Uuid();

/// Health reminders are always server-created (via suggestion rules —
/// see backend `RuleEvaluationService`), so there's nothing to queue for
/// *creating* one. Completing one is the local-first, offline-capable
/// action, following the exact same pattern as
/// `MedicineScheduleRepository.markDoseTaken`.
class HealthReminderRepository {
  HealthReminderRepository({
    required HealthApi api,
    required AppDatabase database,
    required NotificationScheduler notificationScheduler,
  })  : _api = api,
        _db = database,
        _notifications = notificationScheduler;

  final HealthApi _api;
  final AppDatabase _db;
  final NotificationScheduler _notifications;

  /// Re-derives the on-device reminders from the local cache. Works offline.
  Future<void> reconcileLocalNotifications() async {
    final rows = await _db.select(_db.cachedHealthReminders).get();
    await _notifications.reconcileHealthReminders(rows.map(_rowToModel).toList());
  }

  Stream<List<HealthReminderModel>> watchAll() {
    final query = _db.select(_db.cachedHealthReminders)
      ..orderBy([(t) => OrderingTerm.desc(t.scheduledAt)]);
    return query.watch().map((rows) => rows.map(_rowToModel).toList());
  }

  Stream<List<HealthReminderModel>> watchDue() {
    final query = _db.select(_db.cachedHealthReminders)
      ..where((t) => t.status.equals('PENDING'))
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]);
    return query.watch().map(
          (rows) => rows
              .map(_rowToModel)
              .where((r) => !r.scheduledAt.isAfter(DateTime.now()))
              .toList(),
        );
  }

  Stream<List<HealthReminderModel>> watchUpcoming() {
    final query = _db.select(_db.cachedHealthReminders)
      ..where((t) => t.status.equals('PENDING'))
      ..orderBy([(t) => OrderingTerm.asc(t.scheduledAt)]);
    return query.watch().map(
          (rows) => rows.map(_rowToModel).where((r) => r.scheduledAt.isAfter(DateTime.now())).toList(),
        );
  }

  Future<Result<void>> refreshFromServer() async {
    try {
      final reminders = await _api.getReminders();
      final now = DateTime.now();
      await _db.transaction(() async {
        for (final r in reminders) {
          final existing = await (_db.select(_db.cachedHealthReminders)
                ..where((t) => t.id.equals(r.id)))
              .getSingleOrNull();
          // Same race-protection as doses: don't let a refresh clobber a
          // completion the user just did offline.
          final hasUnsyncedLocalChange =
              existing != null && (existing.syncState == 'pending' || existing.syncState == 'syncing');
          if (hasUnsyncedLocalChange) continue;

          await _db.into(_db.cachedHealthReminders).insertOnConflictUpdate(
                CachedHealthRemindersCompanion.insert(
                  id: r.id,
                  title: r.title,
                  description: Value(r.description),
                  scheduledAt: r.scheduledAt,
                  status: r.status,
                  completedAt: Value(r.completedAt),
                  syncState: const Value('synced'),
                  cachedAt: now,
                ),
              );
        }
      });
      await reconcileLocalNotifications();
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  /// Marks [id] COMPLETED immediately, locally — works offline. Queued
  /// for upload via the outbox; see `HealthReminderSyncHandler`.
  Future<void> markComplete(String id) async {
    final existing = await (_db.select(_db.cachedHealthReminders)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing == null || existing.status == 'COMPLETED') return;

    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.cachedHealthReminders)..where((t) => t.id.equals(id))).write(
        CachedHealthRemindersCompanion(
          status: const Value('COMPLETED'),
          completedAt: Value(now),
          syncState: const Value('pending'),
        ),
      );

      await _db.into(_db.outboxEntries).insert(
            OutboxEntriesCompanion.insert(
              id: _uuid.v4(),
              entityType: OutboxEntityType.healthReminderComplete,
              entityLocalId: id,
              operation: OutboxOperation.update,
              payloadJson: jsonEncode({'reminderId': id, 'completedAt': now.toUtc().toIso8601String()}),
              createdAt: now,
            ),
          );
    });
    await _notifications.cancelForHealthReminder(id);
  }

  HealthReminderModel _rowToModel(CachedHealthReminder row) {
    return HealthReminderModel(
      id: row.id,
      title: row.title,
      description: row.description,
      scheduledAt: row.scheduledAt,
      status: row.status,
      completedAt: row.completedAt,
      syncState: row.syncState,
    );
  }
}
