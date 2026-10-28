import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/localization/app_strings.dart';
import '../features/health/domain/health_models.dart';
import '../features/medicine_schedule/domain/medicine_schedule_models.dart';
import 'local_notifications_gateway.dart';
import 'notification_ids.dart';

/// Turns synchronized dose data into on-device notifications, and keeps
/// them reconciled as that data changes — without ever depending on the
/// backend being reachable at the moment a reminder is due (everything
/// here reads from the local cache and schedules with the OS directly).
///
/// Medicine doses due at the same time form one *group* with one reminder:
///  - stage 0 at the scheduled time T: rings (alarm tone) for [ringDuration],
///    then a silent copy stays in the shade;
///  - stage 1 at T+30 if still untaken (or 30 min after the first "Later");
///  - stage 2 only after a second "Later", 30 min later, with no "Later".
/// The server alerts the family at T+62 (DOSE_MISSED_GRACE_MINUTES), after
/// the last possible reminder has finished ringing.
///
/// The core operation is [reconcile]: given "what's currently scheduled"
/// (tracked in [ScheduledMedicineNotifications]) and "what *should* be
/// scheduled" (groups of PENDING doses, from the just-refreshed cache), it
/// diffs the two and only touches what changed. Rows reuse that table with
/// key prefixes, so no Drift schema change was needed:
///  - `grp:<T ms>:<hash of dose ids>`: a scheduled group (a membership
///    change gives a new key, so the old reminder is cancelled and a new one
///    with the right count scheduled);
///  - `snz:<group key>`: a pending "Later" (notificationId = stage,
///    scheduledAt = when it rings);
///  - `health:<reminderId>`: health reminders (plain notifications).
/// Each reconcile kind only ever touches its own rows.
const _healthKeyPrefix = 'health:';
const _groupKeyPrefix = 'grp:';
const _snoozeKeyPrefix = 'snz:';

/// iOS keeps at most 64 pending local notifications and silently drops the
/// rest, so only the soonest ones are scheduled; the next refresh/app-open
/// tops the window up again. Each medicine group uses up to 4.
const _maxScheduledGroups = 12;
const _maxScheduledHealthReminders = 10;

const _doseKind = 'dose';
const _healthKind = 'health';

const repeatAfter = Duration(minutes: 30);
const snoozeFor = Duration(minutes: 30);
const maxReminderStage = 2;

/// Payload `type` of local medicine reminders; same as the backend's
/// backstop push, so taps route to Today's medicine either way.
const medicineReminderType = 'MEDICINE_REMINDER';

/// Doses due at one time that still need a reminder.
class ReminderGroup {
  ReminderGroup(this.at, List<String> doseIds) : doseIds = [...doseIds]..sort();

  final DateTime at;
  final List<String> doseIds;

  String get key =>
      '$_groupKeyPrefix${at.millisecondsSinceEpoch}:${notificationIdForKey(doseIds.join(','))}';

  int ringId(int stage) => notificationIdForKey('$key#$stage');
  int quietId(int stage) => notificationIdForKey('$key#$stage/quiet');

  /// Last moment anything of this group can still ring on its own.
  DateTime get lastAutoReminder => at.add(repeatAfter).add(ringDuration);
}

/// The JSON a reminder carries, read back by the Done / Later actions.
String reminderPayload(DateTime at, int stage) => jsonEncode({
      'type': medicineReminderType,
      'at': at.millisecondsSinceEpoch,
      'stage': stage,
    });

class NotificationScheduler {
  NotificationScheduler({
    required LocalNotificationsGateway gateway,
    required AppDatabase database,
    AppStrings Function()? strings,
    bool Function()? remindersEnabled,
    DateTime Function()? clock,
  })  : _gateway = gateway,
        _db = database,
        _strings = strings ?? (() => enStrings),
        _remindersEnabled = remindersEnabled ?? (() => true),
        _now = clock ?? DateTime.now;

  final LocalNotificationsGateway _gateway;
  final AppDatabase _db;
  final AppStrings Function() _strings;
  final bool Function() _remindersEnabled;
  final DateTime Function() _now;

  /// Alarm mode (exact or not) each kind was last fully scheduled with in
  /// this process. Empty at startup, so the first pass re-registers every
  /// reminder: a force-stop (or a vendor battery saver) wipes all of the
  /// app's alarms, and revoking the exact-alarm permission cancels the exact
  /// ones, while the table below would still say they're scheduled. A later
  /// permission change also re-registers everything in the new mode.
  final _appliedExact = <String, bool>{};

  // ---------------------------------------------------------------------
  // Medicine reminders
  // ---------------------------------------------------------------------

  Future<void> reconcile(List<MedicineDoseModel> allKnownDoses) async {
    final exact = await _gateway.canScheduleExact();
    final rescheduleAll = _appliedExact[_doseKind] != exact;

    final rows = (await _db.select(_db.scheduledMedicineNotifications).get())
        .where((r) => !r.doseId.startsWith(_healthKeyPrefix))
        .toList();
    final snoozes = {
      for (final r in rows.where((r) => r.doseId.startsWith(_snoozeKeyPrefix)))
        r.doseId.substring(_snoozeKeyPrefix.length): r,
    };

    // Rows from before grouping (keyed by bare dose id): cancel once.
    for (final row in rows.where(
      (r) => !r.doseId.startsWith(_groupKeyPrefix) && !r.doseId.startsWith(_snoozeKeyPrefix),
    )) {
      await _cancelKey(row.doseId, row.notificationId);
    }

    final desired = _remindersEnabled()
        ? {for (final g in _groupsFrom(allKnownDoses, snoozes)) g.key: g}
        : <String, ReminderGroup>{};

    final groupRows = rows.where((r) => r.doseId.startsWith(_groupKeyPrefix)).toList();
    for (final row in groupRows) {
      final group = desired[row.doseId];
      final unchanged = !rescheduleAll && group != null && group.at == row.scheduledAt;
      if (!unchanged) await _cancelGroup(row.doseId, keepSnooze: group != null);
    }
    // A snooze whose group is gone (taken, or membership changed).
    for (final key in snoozes.keys.where((k) => !desired.containsKey(k))) {
      await _deleteRow('$_snoozeKeyPrefix$key');
    }

    final existingKeys = {for (final r in groupRows) r.doseId: r.scheduledAt};
    for (final group in desired.values) {
      final alreadyCorrect = !rescheduleAll && existingKeys[group.key] == group.at;
      if (alreadyCorrect) continue;
      await _scheduleGroup(group, snoozes[group.key], exact: exact);
    }
    _appliedExact[_doseKind] = exact;
  }

  /// Called the instant a dose is marked taken locally (optimistic UI), so
  /// its group's reminder updates (fewer medicines) or disappears right away
  /// rather than waiting for the next full [reconcile] pass.
  Future<void> cancelForDose(String doseId) => reconcileFromCache();

  /// [reconcile] against the local dose cache alone.
  Future<void> reconcileFromCache() async {
    final rows = await _db.select(_db.cachedMedicineDoses).get();
    await reconcile(rows.map(_doseFromRow).toList());
  }

  /// Dose ids of the untaken group due at [at], from the local cache.
  Future<List<String>> pendingDoseIdsAt(DateTime at) async =>
      (await _groupAt(at))?.doseIds ?? const [];

  /// "Later" on a reminder at [stage]: the group rings again in
  /// [snoozeFor] at the next stage, replacing its automatic repeat. Ignored
  /// at the last stage (that reminder offers no "Later").
  Future<void> snooze(DateTime at, int stage) async {
    if (stage >= maxReminderStage) return;
    final group = await _groupAt(at);
    if (group == null) return;
    final ringAt = _now().add(snoozeFor);
    final nextStage = stage + 1;
    final exact = await _gateway.canScheduleExact();

    await _cancelGroup(group.key, keepSnooze: false);
    await _upsertRow('$_snoozeKeyPrefix${group.key}', nextStage, ringAt);
    await _ringAndQuiet(group, nextStage, ringAt, exact: exact);
    await _upsertRow(group.key, group.ringId(0), group.at);
  }

  /// Shows the server's backstop push for [at] as this group's stage-1
  /// reminder (same notification id, so it replaces the local repeat rather
  /// than doubling it). Returns false, showing nothing, when the local cache
  /// has no untaken dose at [at]: taken offline and not yet synced.
  Future<bool> showBackstop(DateTime at) async {
    if (!_remindersEnabled()) return false;
    final group = await _groupAt(at);
    if (group == null) return false;
    await _gateway.show(_reminder(group, 1, at, ReminderStyle.ringing));
    return true;
  }

  Future<ReminderGroup?> _groupAt(DateTime at) async {
    final rows = await (_db.select(_db.cachedMedicineDoses)
          ..where((t) => t.scheduledAt.equals(at) & t.doseStatus.equals('PENDING')))
        .get();
    if (rows.isEmpty) return null;
    return ReminderGroup(at, rows.map((r) => r.id).toList());
  }

  List<ReminderGroup> _groupsFrom(
    List<MedicineDoseModel> doses,
    Map<String, ScheduledMedicineNotification> snoozes,
  ) {
    final now = _now();
    final byTime = <DateTime, List<String>>{};
    for (final d in doses.where((d) => d.status == 'PENDING')) {
      byTime.putIfAbsent(d.scheduledAt, () => []).add(d.id);
    }
    final groups = [
      for (final entry in byTime.entries) ReminderGroup(entry.key, entry.value),
    ].where((g) {
      final snoozedUntil = snoozes[g.key]?.scheduledAt;
      final last = snoozedUntil != null ? snoozedUntil.add(ringDuration) : g.lastAutoReminder;
      return last.isAfter(now);
    }).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return groups.take(_maxScheduledGroups).toList();
  }

  Future<void> _scheduleGroup(
    ReminderGroup group,
    ScheduledMedicineNotification? snooze, {
    required bool exact,
  }) async {
    if (snooze != null) {
      await _ringAndQuiet(group, snooze.notificationId, snooze.scheduledAt, exact: exact);
    } else {
      await _ringAndQuiet(group, 0, group.at, exact: exact);
      await _ringAndQuiet(group, 1, group.at.add(repeatAfter), exact: exact);
    }
    await _upsertRow(group.key, group.ringId(0), group.at);
  }

  /// Rings at [ringAt], then leaves a silent copy once the ring is removed.
  /// Parts already in the past are skipped.
  Future<void> _ringAndQuiet(
    ReminderGroup group,
    int stage,
    DateTime ringAt, {
    required bool exact,
  }) async {
    final now = _now();
    final quietAt = ringAt.add(ringDuration);
    if (ringAt.isAfter(now)) {
      await _gateway.schedule(_reminder(group, stage, ringAt, ReminderStyle.ringing), exact: exact);
    }
    if (quietAt.isAfter(now)) {
      await _gateway.schedule(_reminder(group, stage, quietAt, ReminderStyle.quiet), exact: exact);
    }
  }

  ScheduledReminder _reminder(ReminderGroup group, int stage, DateTime at, ReminderStyle style) {
    final s = _strings();
    final time = _formatTime(group.at);
    final count = group.doseIds.length;
    return ScheduledReminder(
      id: style == ReminderStyle.quiet ? group.quietId(stage) : group.ringId(stage),
      title: s.reminderTitle,
      body: count == 1
          ? s.reminderBodyOne.replaceAll('{time}', time)
          : s.reminderBodyMany.replaceAll('{count}', '$count').replaceAll('{time}', time),
      at: at,
      style: style,
      payload: reminderPayload(group.at, stage),
      actions: [
        ReminderAction(reminderActionDone, s.reminderDoneAction),
        if (stage < maxReminderStage) ReminderAction(reminderActionLater, s.reminderLaterAction),
      ],
    );
  }

  /// Cancels every notification a group key may have scheduled (all
  /// stages, ringing and quiet) and forgets it.
  Future<void> _cancelGroup(String key, {required bool keepSnooze}) async {
    for (var stage = 0; stage <= maxReminderStage; stage++) {
      await _gateway.cancel(notificationIdForKey('$key#$stage'));
      await _gateway.cancel(notificationIdForKey('$key#$stage/quiet'));
    }
    await _deleteRow(key);
    if (!keepSnooze) await _deleteRow('$_snoozeKeyPrefix$key');
  }

  // ---------------------------------------------------------------------
  // Health reminders (plain notifications, unchanged behavior)
  // ---------------------------------------------------------------------

  /// Health-reminder counterpart of [reconcile]: schedules an on-device
  /// notification for each upcoming PENDING reminder, cancels those that were
  /// completed/removed/rescheduled. Works entirely offline from the cache.
  Future<void> reconcileHealthReminders(List<HealthReminderModel> reminders) async {
    final exact = await _gateway.canScheduleExact();
    final rescheduleAll = _appliedExact[_healthKind] != exact;
    final now = _now();
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
      if (rescheduleAll || still == null || still.scheduledAt != row.scheduledAt) {
        await _cancelKey(row.doseId, row.notificationId);
      }
    }

    for (final entry in desired.entries) {
      final row = existingByKey[entry.key];
      if (!rescheduleAll && row != null && row.scheduledAt == entry.value.scheduledAt) {
        continue;
      }
      final id = notificationIdForKey(entry.key);
      await _gateway.schedule(
        ScheduledReminder(
          id: id,
          title: entry.value.title,
          body: entry.value.description ?? '',
          at: entry.value.scheduledAt,
        ),
        exact: exact,
      );
      await _upsertRow(entry.key, id, entry.value.scheduledAt);
    }
    _appliedExact[_healthKind] = exact;
  }

  /// Cancels a health reminder's notification immediately (e.g. completed offline).
  Future<void> cancelForHealthReminder(String reminderId) async {
    final key = '$_healthKeyPrefix$reminderId';
    final row = await (_db.select(_db.scheduledMedicineNotifications)
          ..where((t) => t.doseId.equals(key)))
        .getSingleOrNull();
    if (row != null) await _cancelKey(key, row.notificationId);
  }

  Future<void> cancelAll() async {
    final all = await _db.select(_db.scheduledMedicineNotifications).get();
    for (final row in all) {
      if (row.doseId.startsWith(_groupKeyPrefix)) {
        await _cancelGroup(row.doseId, keepSnooze: false);
      } else if (!row.doseId.startsWith(_snoozeKeyPrefix)) {
        await _gateway.cancel(row.notificationId);
      }
    }
    await _db.delete(_db.scheduledMedicineNotifications).go();
    _appliedExact.clear();
  }

  // ---------------------------------------------------------------------
  // Table helpers
  // ---------------------------------------------------------------------

  Future<void> _cancelKey(String key, int notificationId) async {
    await _gateway.cancel(notificationId);
    await _deleteRow(key);
  }

  Future<void> _deleteRow(String key) =>
      (_db.delete(_db.scheduledMedicineNotifications)..where((t) => t.doseId.equals(key))).go();

  Future<void> _upsertRow(String key, int notificationId, DateTime at) =>
      _db.into(_db.scheduledMedicineNotifications).insertOnConflictUpdate(
            ScheduledMedicineNotificationsCompanion.insert(
              doseId: key,
              notificationId: notificationId,
              scheduledAt: at,
            ),
          );

  static MedicineDoseModel _doseFromRow(CachedMedicineDose row) => MedicineDoseModel(
        id: row.id,
        routineId: row.routineId,
        medicineName: row.medicineName,
        dosage: row.dosage,
        scheduledAt: row.scheduledAt,
        status: row.doseStatus,
        takenAt: row.takenAt,
        syncState: row.syncState,
      );

  static String _formatTime(DateTime dt) {
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    return '$hour12:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}
