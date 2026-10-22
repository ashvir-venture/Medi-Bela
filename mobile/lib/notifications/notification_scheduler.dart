import '../core/database/app_database.dart';
import '../features/health/domain/health_models.dart';
import '../features/medicine_schedule/domain/medicine_schedule_models.dart';
import 'local_notifications_gateway.dart';
import 'notification_ids.dart';

/// Turns synchronized dose data into on-device notifications, and keeps
/// them reconciled as that data changes — without ever depending on the
/// backend being reachable at the moment a reminder is due (everything
/// here reads from the local cache and schedules with the OS directly).
///
/// The core operation is [reconcile]: given "what's currently scheduled"
/// (tracked in [ScheduledMedicineNotifications]) and "what *should* be
/// scheduled" (PENDING doses with a future `scheduledAt`, from the just-
/// refreshed cache), it diffs the two and only touches what changed:
///  - a dose that's gone, taken, or missed → its notification is cancelled
///  - a dose whose time changed (routine edited) → cancelled + rescheduled
///  - a dose already correctly scheduled → left alone entirely
///  - a new pending dose → scheduled
/// This is what keeps re-running it after every sync idempotent instead
/// of duplicating or flickering reminders.
/// Rows in `ScheduledMedicineNotifications` for health reminders reuse the
/// same table (keyed `health:<reminderId>`), so no schema change/codegen is
/// needed. Dose reconciliation and health reconciliation each only ever touch
/// their own rows.
const _healthKeyPrefix = 'health:';

/// iOS keeps at most 64 pending local notifications and silently drops the
/// rest, so only the soonest ones are scheduled; the next refresh/app-open
/// tops the window up again.
const _maxScheduledDoses = 48;
const _maxScheduledHealthReminders = 10;

class NotificationScheduler {
  NotificationScheduler({
    required LocalNotificationsGateway gateway,
    required AppDatabase database,
  })  : _gateway = gateway,
        _db = database;

  final LocalNotificationsGateway _gateway;
  final AppDatabase _db;

  Future<void> reconcile(List<MedicineDoseModel> allKnownDoses) async {
    final now = DateTime.now();
    final upcoming = allKnownDoses
        .where((d) => d.status == 'PENDING' && d.scheduledAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final desired = {
      for (final dose in upcoming.take(_maxScheduledDoses)) dose.id: dose,
    };

    final existing = (await _db.select(_db.scheduledMedicineNotifications).get())
        .where((r) => !r.doseId.startsWith(_healthKeyPrefix))
        .toList();
    final existingByDoseId = {for (final row in existing) row.doseId: row};

    // Cancel anything scheduled that's no longer desired, or whose time
    // has changed (an edited routine reschedules doses server-side).
    for (final row in existing) {
      final stillDesired = desired[row.doseId];
      final unchanged = stillDesired != null && stillDesired.scheduledAt == row.scheduledAt;
      if (!unchanged) {
        await _cancel(row.doseId, row.notificationId);
      }
    }

    // Schedule anything desired that isn't already correctly scheduled.
    for (final dose in desired.values) {
      final row = existingByDoseId[dose.id];
      final alreadyCorrect = row != null && row.scheduledAt == dose.scheduledAt;
      if (alreadyCorrect) continue;
      await _schedule(dose);
    }
  }

  /// Health-reminder counterpart of [reconcile]: schedules an on-device
  /// notification for each upcoming PENDING reminder, cancels those that were
  /// completed/removed/rescheduled. Works entirely offline from the cache.
  Future<void> reconcileHealthReminders(List<HealthReminderModel> reminders) async {
    final now = DateTime.now();
    final upcoming = reminders
        .where((r) => r.status == 'PENDING' && r.scheduledAt.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final desired = {
      for (final r in upcoming.take(_maxScheduledHealthReminders))
        '$_healthKeyPrefix${r.id}': r,
    };

    final existing = (await _db.select(_db.scheduledMedicineNotifications).get())
        .where((r) => r.doseId.startsWith(_healthKeyPrefix))
        .toList();
    final existingByKey = {for (final row in existing) row.doseId: row};

    for (final row in existing) {
      final still = desired[row.doseId];
      if (still == null || still.scheduledAt != row.scheduledAt) {
        await _cancel(row.doseId, row.notificationId);
      }
    }

    for (final entry in desired.entries) {
      final row = existingByKey[entry.key];
      if (row != null && row.scheduledAt == entry.value.scheduledAt) continue;
      final id = notificationIdForKey(entry.key);
      await _gateway.zonedSchedule(
        id,
        entry.value.title,
        entry.value.description ?? '',
        entry.value.scheduledAt,
      );
      await _db.into(_db.scheduledMedicineNotifications).insertOnConflictUpdate(
            ScheduledMedicineNotificationsCompanion.insert(
              doseId: entry.key,
              notificationId: id,
              scheduledAt: entry.value.scheduledAt,
            ),
          );
    }
  }

  /// Cancels a health reminder's notification immediately (e.g. completed offline).
  Future<void> cancelForHealthReminder(String reminderId) =>
      cancelForDose('$_healthKeyPrefix$reminderId');

  /// Called the instant a dose is marked taken locally (optimistic UI),
  /// so its reminder disappears immediately rather than waiting for the
  /// next full [reconcile] pass.
  Future<void> cancelForDose(String doseId) async {
    final row = await (_db.select(_db.scheduledMedicineNotifications)
          ..where((t) => t.doseId.equals(doseId)))
        .getSingleOrNull();
    if (row != null) {
      await _cancel(doseId, row.notificationId);
    }
  }

  Future<void> cancelAll() async {
    final all = await _db.select(_db.scheduledMedicineNotifications).get();
    for (final row in all) {
      await _gateway.cancel(row.notificationId);
    }
    await _db.delete(_db.scheduledMedicineNotifications).go();
  }

  Future<void> _schedule(MedicineDoseModel dose) async {
    final id = notificationIdForDose(dose.id);
    await _gateway.zonedSchedule(id, dose.medicineName, dose.dosage, dose.scheduledAt);

    await _db.into(_db.scheduledMedicineNotifications).insertOnConflictUpdate(
          ScheduledMedicineNotificationsCompanion.insert(
            doseId: dose.id,
            notificationId: id,
            scheduledAt: dose.scheduledAt,
          ),
        );
  }

  Future<void> _cancel(String doseId, int notificationId) async {
    await _gateway.cancel(notificationId);
    await (_db.delete(_db.scheduledMedicineNotifications)..where((t) => t.doseId.equals(doseId)))
        .go();
  }
}
