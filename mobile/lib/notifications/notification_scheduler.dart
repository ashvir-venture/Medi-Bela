import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/database/app_database.dart';
import '../core/localization/app_strings.dart';
import '../features/health/domain/health_models.dart';
import '../features/health/domain/personal_reminder_models.dart';
import '../features/medicine_schedule/domain/medicine_schedule_models.dart';
import 'local_notifications_gateway.dart';
import 'notification_ids.dart';
import 'reminder_timing.dart';

/// Turns synchronized dose data into on-device notifications, and keeps
/// them reconciled as that data changes — without ever depending on the
/// backend being reachable at the moment a reminder is due (everything
/// here reads from the local cache and schedules with the OS directly).
///
/// Medicine doses due at the same time form one *group* with one reminder
/// (owner, 2026-10-31: 4 rings, 15 minutes apart, then the family):
///  - stage 0 at the scheduled time T, stages 1-3 at T+15, T+30, T+45 while
///    still untaken; each rings (alarm tone) for [ringDuration], then a
///    silent copy stays in the shade;
///  - "Later" moves the next ring to 15 minutes after the tap, and the
///    following ones every 15 minutes after that; never more than 4 rings
///    and never after T+45 ([ReminderGroup.lastRingAt]), so the last one has
///    no "Later".
/// The server alerts the family at T+50 (DOSE_MISSED_GRACE_MINUTES), after
/// the last possible ring has finished. Test reminders ring once a day for
/// 3 days ([testReminderDays]) until Done.
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
///  - `health:<reminderId>`: health reminders (plain notifications) and test
///    reminders (one ringing reminder per day, ids from `health:<id>#<day>`).
/// Each reconcile kind only ever touches its own rows.
const _healthKeyPrefix = 'health:';
const _personalKeyPrefix = 'pr:';
/// Round 15-16 reminders worked out from my care and health records:
/// `care:<kind>:<id>:<ms>` (visit, check-up, chemo, test, dialysis, pen).
const _careKeyPrefix = 'care:';
const _careKind = 'care';
/// How many care reminders are kept on the OS at a time (topped up on refresh).
const _maxScheduledCare = 16;

/// Payload `type` of a care reminder; `route` is the page it opens.
const careReminderType = 'CARE_REMINDER';
const _groupKeyPrefix = 'grp:';
const _snoozeKeyPrefix = 'snz:';

/// iOS keeps at most 64 pending local notifications and silently drops the
/// rest, so only the soonest ones are scheduled; the next refresh/app-open
/// tops the window up again. Each medicine group uses up to 4 there
/// (Android also keeps a silent copy of each), each test reminder up to 3.
const _maxScheduledGroups = 12;
const _maxScheduledHealthReminders = 5;

const _doseKind = 'dose';
const _healthKind = 'health';
const _personalKind = 'personal';

// From the server's .env with the user's own values on top (ReminderTiming):
// ring gap, rings, Later delay. Defaults 15 minutes x 4 rings, Later 15.
Duration get repeatAfter => Duration(minutes: ReminderTiming.current.repeatMinutes);
Duration get snoozeFor => Duration(minutes: ReminderTiming.current.laterMinutes);
int get maxReminderStage => ReminderTiming.current.rings - 1;

/// No medicine ring after this long past the dose time (the last automatic one).
Duration get lastRingAfter => repeatAfter * maxReminderStage;

/// Cancelling covers every stage / day a past setting may have scheduled.
const _maxStagesEver = 10;
const _maxTestDaysEver = 14;

/// Payload `type` of local medicine reminders; same as the backend's
/// backstop push, so taps open the reminder page either way.
const medicineReminderType = 'MEDICINE_REMINDER';

/// Payload `type` of a test reminder (one of its three days).
const testReminderType = 'TEST_REMINDER';

/// Payload `type` of a personal reminder (Round 13).
const personalReminderType = 'PERSONAL_REMINDER';

/// How far ahead personal reminders are put on the OS (topped up on every
/// refresh / app start; iOS keeps 64 in all).
const _personalWindow = Duration(days: 2);
const _maxScheduledPersonal = 8;

/// Doses due at one time that still need a reminder.
class ReminderGroup {
  ReminderGroup(this.at, List<String> doseIds) : doseIds = [...doseIds]..sort();

  final DateTime at;
  final List<String> doseIds;

  String get key =>
      '$_groupKeyPrefix${at.millisecondsSinceEpoch}:${notificationIdForKey(doseIds.join(','))}';

  int ringId(int stage) => notificationIdForKey('$key#$stage');
  int quietId(int stage) => notificationIdForKey('$key#$stage/quiet');

  /// No ring of this group starts after this (the 4th automatic one).
  DateTime get lastRingAt => at.add(lastRingAfter);

  /// Last moment anything of this group can still ring.
  DateTime get lastAutoReminder => lastRingAt.add(ringDuration);

  /// The last ring offers Done only: stage 3, or one at the T+45 limit.
  bool isLastRing(int stage, DateTime ringAt) =>
      stage >= maxReminderStage || !ringAt.isBefore(lastRingAt);
}

/// The ring times of a group from [stage] on: [first], then every
/// [repeatAfter], up to stage 3 and never after [ReminderGroup.lastRingAt].
List<(int, DateTime)> ringPlan(ReminderGroup group, int stage, DateTime first) => [
      for (var s = stage; s <= maxReminderStage; s++)
        if (!first.add(repeatAfter * (s - stage)).isAfter(group.lastRingAt))
          (s, first.add(repeatAfter * (s - stage))),
    ];

/// The JSON a reminder carries, read back by the Done / Later actions.
String reminderPayload(DateTime at, int stage) => jsonEncode({
      'type': medicineReminderType,
      'at': at.millisecondsSinceEpoch,
      'stage': stage,
    });

/// A personal reminder's payload: which one, which ring, and whether Later
/// should tell the caregiver who set it up.
String personalReminderPayload(String reminderId, DateTime at, bool byCaregiver) => jsonEncode({
      'type': personalReminderType,
      'reminderId': reminderId,
      'at': at.millisecondsSinceEpoch,
      'byCaregiver': byCaregiver,
    });

/// A test reminder's payload: which reminder, which of its days (0-2).
String testReminderPayload(String reminderId, int day) => jsonEncode({
      'type': testReminderType,
      'reminderId': reminderId,
      'day': day,
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

  /// The server changed a timing (ReminderTiming): the next reconcile of
  /// each kind registers everything again with the new times.
  void timingChanged() => _appliedExact.clear();

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
        .where((r) =>
            !r.doseId.startsWith(_healthKeyPrefix) &&
            !r.doseId.startsWith(_personalKeyPrefix) &&
            !r.doseId.startsWith(_careKeyPrefix))
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
  /// [snoozeFor] at the next stage (then every 15 minutes), replacing its
  /// automatic repeats, but never after T+45. Ignored on the last ring
  /// (that reminder offers no "Later").
  Future<void> snooze(DateTime at, int stage) async {
    if (stage >= maxReminderStage) return;
    final group = await _groupAt(at);
    if (group == null) return;
    final now = _now();
    if (!now.isBefore(group.lastRingAt)) return;
    final wanted = now.add(snoozeFor);
    final ringAt = wanted.isAfter(group.lastRingAt) ? group.lastRingAt : wanted;
    final nextStage = stage + 1;
    final exact = await _gateway.canScheduleExact();

    await _cancelGroup(group.key, keepSnooze: false);
    await _upsertRow('$_snoozeKeyPrefix${group.key}', nextStage, ringAt);
    for (final (s, ring) in ringPlan(group, nextStage, ringAt)) {
      await _ringAndQuiet(group, s, ring, exact: exact);
    }
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
    ].where((g) => g.lastAutoReminder.isAfter(now)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return groups.take(_maxScheduledGroups).toList();
  }

  Future<void> _scheduleGroup(
    ReminderGroup group,
    ScheduledMedicineNotification? snooze, {
    required bool exact,
  }) async {
    final plan = snooze != null
        ? ringPlan(group, snooze.notificationId, snooze.scheduledAt)
        : ringPlan(group, 0, group.at);
    for (final (stage, ringAt) in plan) {
      await _ringAndQuiet(group, stage, ringAt, exact: exact);
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
      await _gateway.schedule(
        _reminder(group, stage, ringAt, ReminderStyle.ringing, ringAt: ringAt),
        exact: exact,
      );
    }
    if (quietAt.isAfter(now)) {
      await _gateway.schedule(
        _reminder(group, stage, quietAt, ReminderStyle.quiet, ringAt: ringAt),
        exact: exact,
      );
    }
  }

  ScheduledReminder _reminder(
    ReminderGroup group,
    int stage,
    DateTime at,
    ReminderStyle style, {
    DateTime? ringAt,
  }) {
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
        ReminderAction(reminderActionDone, s.takenAction),
        if (!group.isLastRing(stage, ringAt ?? at))
          ReminderAction(reminderActionLater, s.reminderLaterAction),
      ],
    );
  }

  /// Cancels every notification a group key may have scheduled (all
  /// stages, ringing and quiet) and forgets it.
  Future<void> _cancelGroup(String key, {required bool keepSnooze}) async {
    for (var stage = 0; stage < _maxStagesEver; stage++) {
      await _gateway.cancel(notificationIdForKey('$key#$stage'));
      await _gateway.cancel(notificationIdForKey('$key#$stage/quiet'));
    }
    await _deleteRow(key);
    if (!keepSnooze) await _deleteRow('$_snoozeKeyPrefix$key');
  }

  // ---------------------------------------------------------------------
  // Health reminders (plain notifications) and test reminders (ringing,
  // once a day for [testReminderDays] days, Done / Later)
  // ---------------------------------------------------------------------

  /// Health-reminder counterpart of [reconcile]: schedules an on-device
  /// notification for each upcoming PENDING reminder, cancels those that were
  /// completed/removed/rescheduled. Works entirely offline from the cache.
  Future<void> reconcileHealthReminders(List<HealthReminderModel> reminders) async {
    final exact = await _gateway.canScheduleExact();
    final rescheduleAll = _appliedExact[_healthKind] != exact;
    final now = _now();
    final upcoming = reminders
        .where((r) => r.status == 'PENDING' && _lastHealthRing(r).isAfter(now))
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
        await _cancelHealthKey(row.doseId, row.notificationId);
      }
    }

    for (final entry in desired.entries) {
      final row = existingByKey[entry.key];
      if (!rescheduleAll && row != null && row.scheduledAt == entry.value.scheduledAt) {
        continue;
      }
      final id = notificationIdForKey(entry.key);
      if (entry.value.isTest) {
        await _scheduleTestReminder(entry.key, entry.value, exact: exact);
      } else {
        await _gateway.schedule(
          ScheduledReminder(
            id: id,
            title: entry.value.title,
            body: entry.value.description ?? '',
            at: entry.value.scheduledAt,
          ),
          exact: exact,
        );
      }
      await _upsertRow(entry.key, id, entry.value.scheduledAt);
    }
    _appliedExact[_healthKind] = exact;
  }

  DateTime _lastHealthRing(HealthReminderModel r) => r.isTest
      ? r.scheduledAt.add(Duration(days: testReminderDays - 1)).add(ringDuration)
      : r.scheduledAt;

  /// A test rings at its time on each of its days still ahead. Neutral text
  /// (no test name): the lock screen is often shared.
  Future<void> _scheduleTestReminder(
    String key,
    HealthReminderModel reminder, {
    required bool exact,
  }) async {
    final s = _strings();
    final now = _now();
    for (var day = 0; day < testReminderDays; day++) {
      final ringAt = reminder.scheduledAt.add(Duration(days: day));
      final last = day == testReminderDays - 1;
      for (final style in [ReminderStyle.ringing, ReminderStyle.quiet]) {
        final at = style == ReminderStyle.ringing ? ringAt : ringAt.add(ringDuration);
        if (!at.isAfter(now)) continue;
        await _gateway.schedule(
          ScheduledReminder(
            id: notificationIdForKey('$key#$day${style == ReminderStyle.quiet ? '/quiet' : ''}'),
            title: s.testReminderTitle,
            body: s.testReminderBody,
            at: at,
            style: style,
            payload: testReminderPayload(reminder.id, day),
            actions: [
              ReminderAction(reminderActionDone, s.testDoneAction),
              if (!last) ReminderAction(reminderActionLater, s.testLaterAction),
            ],
          ),
          exact: exact,
        );
      }
    }
  }

  /// Personal reminders (Round 13): a banner with Done / Later at each ring in
  /// the next two days ("Time for your {name}", then the description). Works
  /// from the local copy, offline; each refresh tops it up.
  Future<void> reconcilePersonalReminders(List<PersonalReminderModel> reminders) async {
    final exact = await _gateway.canScheduleExact();
    final rescheduleAll = _appliedExact[_personalKind] != exact;
    final now = _now();
    final s = _strings();
    final rings = <(String, PersonalReminderModel, DateTime)>[
      if (_remindersEnabled())
        for (final r in reminders)
          for (final at in r.occurrences(now, now.add(_personalWindow))) ('$_personalKeyPrefix${r.id}:${at.millisecondsSinceEpoch}', r, at),
    ]..sort((a, b) => a.$3.compareTo(b.$3));
    final desired = {for (final ring in rings.take(_maxScheduledPersonal)) ring.$1: ring};

    final existing = (await _db.select(_db.scheduledMedicineNotifications).get())
        .where((r) => r.doseId.startsWith(_personalKeyPrefix))
        .toList();
    for (final row in existing) {
      if (rescheduleAll || !desired.containsKey(row.doseId)) await _cancelKey(row.doseId, row.notificationId);
    }
    final kept = {for (final row in existing) row.doseId};
    for (final entry in desired.entries) {
      if (!rescheduleAll && kept.contains(entry.key)) continue;
      final (key, reminder, at) = entry.value;
      final id = notificationIdForKey(key);
      await _gateway.schedule(
        ScheduledReminder(
          id: id,
          title: s.personalReminderTitle.replaceAll('{name}', reminder.name),
          body: reminder.description ?? '',
          at: at,
          style: ReminderStyle.banner,
          payload: personalReminderPayload(reminder.id, at, reminder.byCaregiver),
          actions: [
            ReminderAction(reminderActionDone, s.testDoneAction),
            ReminderAction(reminderActionLater, s.personalLaterAction),
          ],
        ),
        exact: exact,
      );
      await _upsertRow(key, id, at);
    }
    _appliedExact[_personalKind] = exact;
  }

  /// Round 15-16 care reminders (visits and check-ups the day before at
  /// 19:00, own tests the day before at 09:00, dialysis an hour before a
  /// session, the insulin pen before it expires): plain banners with neutral
  /// lock-screen text, worked out from the cached care and records. Keeps
  /// the next [_maxScheduledCare]; each refresh tops them up.
  Future<void> reconcileCareReminders(List<CareReminderItem> items) async {
    final exact = await _gateway.canScheduleExact();
    final rescheduleAll = _appliedExact[_careKind] != exact;
    final now = _now();
    final upcoming = [
      if (_remindersEnabled())
        for (final i in items)
          if (i.at.isAfter(now)) i,
    ]..sort((a, b) => a.at.compareTo(b.at));
    final desired = {for (final i in upcoming.take(_maxScheduledCare)) '$_careKeyPrefix${i.key}:${i.at.millisecondsSinceEpoch}': i};

    final existing = (await _db.select(_db.scheduledMedicineNotifications).get())
        .where((r) => r.doseId.startsWith(_careKeyPrefix))
        .toList();
    for (final row in existing) {
      if (rescheduleAll || !desired.containsKey(row.doseId)) await _cancelKey(row.doseId, row.notificationId);
    }
    final kept = {for (final row in existing) row.doseId};
    for (final entry in desired.entries) {
      if (!rescheduleAll && kept.contains(entry.key)) continue;
      final item = entry.value;
      final id = notificationIdForKey(entry.key);
      await _gateway.schedule(
        ScheduledReminder(
          id: id,
          title: item.title,
          body: item.body,
          at: item.at,
          style: ReminderStyle.banner,
          payload: jsonEncode({'type': careReminderType, 'route': item.route}),
        ),
        exact: exact,
      );
      await _upsertRow(entry.key, id, item.at);
    }
    _appliedExact[_careKind] = exact;
  }

  /// Cancels a key's own notification and, for a test reminder, its daily ones.
  Future<void> _cancelHealthKey(String key, int notificationId) async {
    for (var day = 0; day < _maxTestDaysEver; day++) {
      await _gateway.cancel(notificationIdForKey('$key#$day'));
      await _gateway.cancel(notificationIdForKey('$key#$day/quiet'));
    }
    await _cancelKey(key, notificationId);
  }

  /// "Later" on a test reminder: only today's notification goes (the action
  /// already removed it); the next day's ring stays as scheduled.
  Future<void> dismissTestReminderDay(String reminderId, int day) async {
    final key = '$_healthKeyPrefix$reminderId';
    await _gateway.cancel(notificationIdForKey('$key#$day'));
    await _gateway.cancel(notificationIdForKey('$key#$day/quiet'));
  }

  /// Cancels a health reminder's notification immediately (e.g. completed offline).
  Future<void> cancelForHealthReminder(String reminderId) async {
    final key = '$_healthKeyPrefix$reminderId';
    final row = await (_db.select(_db.scheduledMedicineNotifications)
          ..where((t) => t.doseId.equals(key)))
        .getSingleOrNull();
    if (row != null) await _cancelHealthKey(key, row.notificationId);
  }

  Future<void> cancelAll() async {
    final all = await _db.select(_db.scheduledMedicineNotifications).get();
    for (final row in all) {
      if (row.doseId.startsWith(_groupKeyPrefix)) {
        await _cancelGroup(row.doseId, keepSnooze: false);
      } else if (row.doseId.startsWith(_healthKeyPrefix)) {
        await _cancelHealthKey(row.doseId, row.notificationId);
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

/// One care reminder ready for the OS (see NotificationScheduler.reconcileCareReminders).
class CareReminderItem {
  const CareReminderItem({required this.key, required this.at, required this.title, required this.body, required this.route});

  /// Stable per source (e.g. `visit:<id>`); the time is added to the row key.
  final String key;
  final DateTime at;
  final String title;
  final String body;
  final String route;
}
