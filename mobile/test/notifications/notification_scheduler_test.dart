import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/features/health/domain/health_models.dart';
import 'package:mobile/features/medicine_schedule/domain/medicine_schedule_models.dart';
import 'package:mobile/notifications/local_notifications_gateway.dart';
import 'package:mobile/notifications/notification_scheduler.dart';

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

  tearDown(() => db.close());

  group('grouped medicine reminders', () {
    test('one reminder per time: ring at T, silent copy at T+2, repeat at T+30', () async {
      await scheduler.reconcile([_dose('d1', t8), _dose('d2', t8)]);

      final times = gateway.scheduled.values.map((s) => (s.reminder.style, s.reminder.at)).toSet();
      expect(times, {
        (ReminderStyle.ringing, t8),
        (ReminderStyle.quiet, t8.add(const Duration(minutes: 2))),
        (ReminderStyle.ringing, t8.add(const Duration(minutes: 30))),
        (ReminderStyle.quiet, t8.add(const Duration(minutes: 32))),
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

    test('first two stages offer Done and Later', () async {
      await scheduler.reconcile([_dose('d1', t8)]);
      for (final r in gateway.ringing) {
        expect(r.actions.map((a) => a.id), [reminderActionDone, reminderActionLater]);
      }
    });

    test('a dose already past T still gets its 30-minute repeat', () async {
      clock = t8.add(const Duration(minutes: 10));
      await makeScheduler().reconcile([_dose('d1', t8)]);

      expect(gateway.ringing.map((r) => r.at), [t8.add(const Duration(minutes: 30))]);
    });

    test('taking one dose shrinks the group to the rest', () async {
      await cacheDose('d1', t8);
      await cacheDose('d2', t8);
      await scheduler.reconcileFromCache();

      await cacheDose('d1', t8, status: 'TAKEN');
      await scheduler.cancelForDose('d1');

      expect(gateway.ringing, hasLength(2));
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
    test('snoozes 30 minutes from the press, replacing the automatic repeat', () async {
      await cacheDose('d1', t8);
      await scheduler.reconcileFromCache();

      clock = t8.add(const Duration(minutes: 1));
      await scheduler.snooze(t8, 0);

      expect(gateway.ringing.map((r) => r.at), [t8.add(const Duration(minutes: 31))]);
    });

    test('second Later gives a last reminder without Later; a third is ignored', () async {
      await cacheDose('d1', t8);
      await scheduler.reconcileFromCache();
      clock = t8.add(const Duration(minutes: 1));
      await scheduler.snooze(t8, 0);
      clock = t8.add(const Duration(minutes: 31));
      await scheduler.snooze(t8, 1);

      final last = gateway.ringing.single;
      expect(last.at, t8.add(const Duration(minutes: 61)));
      expect(last.actions.map((a) => a.id), [reminderActionDone]);

      await scheduler.snooze(t8, maxReminderStage);
      expect(gateway.ringing.single.at, t8.add(const Duration(minutes: 61)));
    });

    test('a snooze survives an app restart (process-start re-registration)', () async {
      await cacheDose('d1', t8);
      await scheduler.reconcileFromCache();
      clock = t8.add(const Duration(minutes: 31));
      await scheduler.snooze(t8, 1);

      gateway.scheduled.clear();
      await makeScheduler().reconcileFromCache();

      expect(gateway.ringing.single.at, t8.add(const Duration(minutes: 61)));
    });
  });

  group('backstop push', () {
    test('dropped when the local database shows the doses taken', () async {
      await cacheDose('d1', t8, status: 'TAKEN');
      expect(await scheduler.showBackstop(t8), isFalse);
      expect(gateway.shown, isEmpty);
    });

    test('shown as the group\'s second reminder (same id as the local repeat)', () async {
      await cacheDose('d1', t8);
      await scheduler.reconcileFromCache();
      final localRepeat = gateway.ringing.last;

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
      expect(gateway.scheduled, hasLength(4));

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
