import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/features/health/domain/health_models.dart';
import 'package:mobile/features/medicine_schedule/domain/medicine_schedule_models.dart';
import 'package:mobile/notifications/local_notifications_gateway.dart';
import 'package:mobile/notifications/notification_scheduler.dart';
import 'package:mobile/notifications/reminder_timing.dart';

class _Scheduled {
  _Scheduled(this.reminder, this.exact);
  final ScheduledReminder reminder;
  final bool exact;
}

class _FakeGateway implements LocalNotificationsGateway {
  bool exactAllowed = true;
  final scheduled = <int, _Scheduled>{};
  final shown = <ScheduledReminder>[];
  int scheduleCalls = 0;

  @override
  Future<void> schedule(ScheduledReminder reminder, {required bool exact}) async {
    scheduleCalls++;
    scheduled[reminder.id] = _Scheduled(reminder, exact);
  }

  @override
  Future<void> show(ScheduledReminder reminder) async => shown.add(reminder);

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);

  @override
  Future<bool> canScheduleExact() async => exactAllowed;

  List<ScheduledReminder> get ringing => [
        for (final s in scheduled.values)
          if (s.reminder.style == ReminderStyle.ringing) s.reminder,
      ]..sort((a, b) => a.at.compareTo(b.at));
}

// Whole seconds: Drift stores DateTime at second precision.
final now = DateTime(2026, 10, 29, 7, 0);
final t8 = DateTime(2026, 10, 29, 8, 0);

MedicineDoseModel _dose(String id, DateTime at, {String status = 'PENDING'}) => MedicineDoseModel(
      id: id,
      routineId: 'r1',
      medicineName: 'Napa',
      dosage: '1 tablet',
      scheduledAt: at,
      status: status,
    );

void main() {
  late AppDatabase db;
  late _FakeGateway gateway;
  late bool remindersOn;
  late NotificationScheduler scheduler;
  late DateTime clock;

  NotificationScheduler makeScheduler() => NotificationScheduler(
        gateway: gateway,
        database: db,
        strings: () => enStrings,
        remindersEnabled: () => remindersOn,
        clock: () => clock,
      );

  Future<void> cacheDose(String id, DateTime at, {String status = 'PENDING'}) =>
      db.into(db.cachedMedicineDoses).insertOnConflictUpdate(
            CachedMedicineDosesCompanion.insert(
              id: id,
              routineId: 'r1',
              medicineName: 'Napa',
              dosage: '1 tablet',
              scheduledAt: at,
              doseStatus: status,
              cachedAt: now,
            ),
          );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = _FakeGateway();
    remindersOn = true;
    clock = now;
    scheduler = makeScheduler();
  });

  tearDown(() {
    ReminderTiming.current = const ReminderTiming();
    return db.close();
  });

  // Owner, 2026-10-31: the timings come from the server's .env (GET /app-config).
  test('server timings change the rings: every 10 min, 3 rings, Later until the last', () async {
    ReminderTiming.current = ReminderTiming.fromJson({'repeatMinutes': 10, 'rings': 3, 'ringMinutes': 1});
    await scheduler.reconcile([_dose('d1', t8)]);
    final times = gateway.scheduled.values.map((s) => (s.reminder.style, s.reminder.at)).toSet();
    expect(times, {
      for (final m in [0, 10, 20]) ...{
        (ReminderStyle.ringing, t8.add(Duration(minutes: m))),
        (ReminderStyle.quiet, t8.add(Duration(minutes: m + 1))),
      },
    });
    expect(gateway.ringing.last.actions.map((a) => a.id), [reminderActionDone]);
  });

  test('junk from the server falls back to the defaults', () {
    final t = ReminderTiming.fromJson({'repeatMinutes': 0, 'rings': 'x'});
    expect([t.repeatMinutes, t.rings, t.takenClosesBeforeNextMinutes], [15, 4, 60]);
  });

  group('grouped medicine reminders', () {
    // Owner, 2026-10-31: 4 rings, 15 minutes apart, then the family.
    test('one reminder per time: rings at T, T+15, T+30, T+45, each with a silent copy 2 min later', () async {
      await scheduler.reconcile([_dose('d1', t8), _dose('d2', t8)]);

      final times = gateway.scheduled.values.map((s) => (s.reminder.style, s.reminder.at)).toSet();
      expect(times, {
        for (final m in [0, 15, 30, 45]) ...{
          (ReminderStyle.ringing, t8.add(Duration(minutes: m))),
          (ReminderStyle.quiet, t8.add(Duration(minutes: m + 2))),
        },
      });
    });

    test('text is neutral: a count and a time, never medicine names', () async {
      await scheduler.reconcile([_dose('d1', t8), _dose('d2', t8)]);

      for (final s in gateway.scheduled.values) {
        expect(s.reminder.title, enStrings.reminderTitle);
        expect(s.reminder.body, contains('2 medicines'));
        expect(s.reminder.body, contains('8:00 AM'));
        expect('${s.reminder.title} ${s.reminder.body}', isNot(contains('Napa')));
      }
    });

    test('the first three rings offer Done and Later, the 4th Done only', () async {
      await scheduler.reconcile([_dose('d1', t8)]);
      final rings = gateway.ringing;
      expect(rings, hasLength(4));
      for (final r in rings.take(3)) {
        expect(r.actions.map((a) => a.id), [reminderActionDone, reminderActionLater]);
      }
      expect(rings.last.actions.map((a) => a.id), [reminderActionDone]);
    });

    test('a dose already past T still gets the repeats still ahead', () async {
      clock = t8.add(const Duration(minutes: 10));
      await makeScheduler().reconcile([_dose('d1', t8)]);

      expect(gateway.ringing.map((r) => r.at), [
        t8.add(const Duration(minutes: 15)),
        t8.add(const Duration(minutes: 30)),
        t8.add(const Duration(minutes: 45)),
      ]);
    });

    test('taking one dose shrinks the group to the rest', () async {
      await cacheDose('d1', t8);
      await cacheDose('d2', t8);
      await scheduler.reconcileFromCache();

      await cacheDose('d1', t8, status: 'TAKEN');
      await scheduler.cancelForDose('d1');

      expect(gateway.ringing, hasLength(4));
      expect(gateway.ringing.first.body, contains('A medicine'));
    });

    test('turning reminders off cancels everything and schedules nothing', () async {
      await scheduler.reconcile([_dose('d1', t8)]);
      remindersOn = false;
      await scheduler.reconcile([_dose('d1', t8)]);

      expect(gateway.scheduled, isEmpty);
    });
  });

  group('Later', () {
    test('rings again 15 minutes after the press, then every 15, never after T+45', () async {
      await cacheDose('d1', t8);
      await scheduler.reconcileFromCache();

      clock = t8.add(const Duration(minutes: 1));
      await scheduler.snooze(t8, 0);

      expect(gateway.ringing.map((r) => r.at), [
        t8.add(const Duration(minutes: 16)),
        t8.add(const Duration(minutes: 31)),
      ]);
      // The ring at the T+45 limit would be the 5th: never more than 4 in all.
      expect(gateway.ringing.last.actions.map((a) => a.id), [reminderActionDone, reminderActionLater]);
    });

    test('a Later close to the limit rings once more at T+45, Done only; Later on it is ignored', () async {
      await cacheDose('d1', t8);
      await scheduler.reconcileFromCache();
      clock = t8.add(const Duration(minutes: 31));
      await scheduler.snooze(t8, 2);

      final last = gateway.ringing.single;
      expect(last.at, t8.add(const Duration(minutes: 45)));
      expect(last.actions.map((a) => a.id), [reminderActionDone]);

      clock = t8.add(const Duration(minutes: 45));
      await scheduler.snooze(t8, maxReminderStage);
      expect(gateway.ringing.single.at, t8.add(const Duration(minutes: 45)));
    });

    test('a snooze survives an app restart (process-start re-registration)', () async {
      await cacheDose('d1', t8);
      await scheduler.reconcileFromCache();
      clock = t8.add(const Duration(minutes: 20));
      await scheduler.snooze(t8, 1);

      gateway.scheduled.clear();
      await makeScheduler().reconcileFromCache();

      expect(gateway.ringing.map((r) => r.at), [t8.add(const Duration(minutes: 35))]);
    });
  });

  group('backstop push', () {
    test('dropped when the local database shows the doses taken', () async {
      await cacheDose('d1', t8, status: 'TAKEN');
      expect(await scheduler.showBackstop(t8), isFalse);
      expect(gateway.shown, isEmpty);
    });

    test('shown as the group\'s second reminder (same id as the local repeat at T+15)', () async {
      await cacheDose('d1', t8);
      await scheduler.reconcileFromCache();
      final localRepeat = gateway.ringing[1];

      expect(await scheduler.showBackstop(t8), isTrue);
      expect(gateway.shown.single.id, localRepeat.id);
    });

    test('dropped when medicine reminders are off', () async {
      await cacheDose('d1', t8);
      remindersOn = false;
      expect(await scheduler.showBackstop(t8), isFalse);
    });
  });

  group('exact alarms', () {
    test('schedules exact alarms when the permission is granted', () async {
      await scheduler.reconcile([_dose('d1', t8)]);
      expect(gateway.scheduled.values.map((s) => s.exact).toSet(), {true});
    });

    test('falls back to inexact alarms when the permission is denied', () async {
      gateway.exactAllowed = false;
      await scheduler.reconcile([_dose('d1', t8)]);
      expect(gateway.scheduled.values.map((s) => s.exact).toSet(), {false});
    });

    test('a later grant re-registers existing reminders as exact', () async {
      gateway.exactAllowed = false;
      await scheduler.reconcile([_dose('d1', t8)]);
      gateway.exactAllowed = true;
      await scheduler.reconcile([_dose('d1', t8)]);
      expect(gateway.scheduled.values.map((s) => s.exact).toSet(), {true});
    });

    test('re-registers everything once per process, then stays idempotent', () async {
      await scheduler.reconcile([_dose('d1', t8)]);

      // An app restart after a force-stop wiped the OS alarms: the table
      // still lists the group, but a fresh scheduler registers it again.
      gateway.scheduled.clear();
      final restarted = makeScheduler();
      await restarted.reconcile([_dose('d1', t8)]);
      expect(gateway.scheduled, hasLength(8));

      final callsBefore = gateway.scheduleCalls;
      await restarted.reconcile([_dose('d1', t8)]);
      expect(gateway.scheduleCalls, callsBefore);
    });

    test('health reminders follow the same exact/inexact rule, as plain notifications', () async {
      gateway.exactAllowed = false;
      final reminder = HealthReminderModel(id: 'h1', title: 'Check sugar', scheduledAt: t8, status: 'PENDING');

      await scheduler.reconcileHealthReminders([reminder]);
      gateway.exactAllowed = true;
      await scheduler.reconcileHealthReminders([reminder]);

      final only = gateway.scheduled.values.single;
      expect(only.exact, isTrue);
      expect(only.reminder.style, ReminderStyle.plain);
    });
  });

  group('test reminders', () {
    HealthReminderModel test0({String status = 'PENDING'}) =>
        HealthReminderModel(id: 't1', title: 'CBC', scheduledAt: t8, status: status, kind: 'TEST');

    test('ring on their day and the next two, neutral text, Later until the last day', () async {
      await scheduler.reconcileHealthReminders([test0()]);

      final rings = gateway.ringing;
      expect(rings.map((r) => r.at), [
        t8,
        t8.add(const Duration(days: 1)),
        t8.add(const Duration(days: 2)),
      ]);
      for (final r in rings) {
        expect('${r.title} ${r.body}', isNot(contains('CBC')));
        expect(r.payload, contains('TEST_REMINDER'));
      }
      expect(rings.first.actions.map((a) => a.id), [reminderActionDone, reminderActionLater]);
      expect(rings.last.actions.map((a) => a.id), [reminderActionDone]);
    });

    test('Later clears only today: tomorrow still rings', () async {
      await scheduler.reconcileHealthReminders([test0()]);
      await scheduler.dismissTestReminderDay('t1', 0);
      expect(gateway.ringing.map((r) => r.at), [t8.add(const Duration(days: 1)), t8.add(const Duration(days: 2))]);
    });

    test('done: every remaining day is cancelled', () async {
      await scheduler.reconcileHealthReminders([test0()]);
      await scheduler.reconcileHealthReminders([test0(status: 'COMPLETED')]);
      expect(gateway.scheduled, isEmpty);
    });

    test('on day 2 the days still ahead keep ringing', () async {
      clock = t8.add(const Duration(days: 1, hours: 1));
      await makeScheduler().reconcileHealthReminders([test0()]);
      expect(gateway.ringing.map((r) => r.at), [t8.add(const Duration(days: 2))]);
    });
  });

  test('rows from before grouping (per-dose keys) are cancelled once', () async {
    await db.into(db.scheduledMedicineNotifications).insert(
          ScheduledMedicineNotificationsCompanion.insert(doseId: 'old-dose', notificationId: 42, scheduledAt: t8),
        );
    gateway.scheduled[42] = _Scheduled(
      ScheduledReminder(id: 42, title: 'x', body: 'y', at: t8),
      true,
    );

    await scheduler.reconcile([_dose('d1', t8)]);

    expect(gateway.scheduled.containsKey(42), isFalse);
    final keys = (await db.select(db.scheduledMedicineNotifications).get()).map((r) => r.doseId);
    expect(keys.where((k) => k == 'old-dose'), isEmpty);
  });

}
