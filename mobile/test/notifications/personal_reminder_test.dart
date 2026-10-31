import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/database/app_database.dart';
import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/features/health/domain/personal_reminder_models.dart';
import 'package:mobile/notifications/local_notifications_gateway.dart';
import 'package:mobile/notifications/notification_scheduler.dart';

class _Gateway implements LocalNotificationsGateway {
  final scheduled = <int, ScheduledReminder>{};

  @override
  Future<void> schedule(ScheduledReminder reminder, {required bool exact}) async => scheduled[reminder.id] = reminder;

  @override
  Future<void> show(ScheduledReminder reminder) async {}

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);

  @override
  Future<bool> canScheduleExact() async => true;
}

void main() {
  final walk = PersonalReminderModel(
    id: 'p1',
    name: 'walk',
    description: '30 minutes after breakfast',
    scheduleTimes: const ['07:00', '18:00'],
    intervalDays: 2,
    startDate: DateTime(2026, 11, 1),
    byCaregiver: true,
  );

  test('rings at its times on every Nth day from the start day', () {
    final rings = walk.occurrences(DateTime(2026, 10, 31), DateTime(2026, 11, 6));
    expect(rings, [
      DateTime(2026, 11, 1, 7),
      DateTime(2026, 11, 1, 18),
      DateTime(2026, 11, 3, 7),
      DateTime(2026, 11, 3, 18),
      DateTime(2026, 11, 5, 7),
      DateTime(2026, 11, 5, 18),
    ]);
  });

  test('stops after its last day', () {
    final short = PersonalReminderModel(
      id: 'p2',
      name: 'x',
      scheduleTimes: const ['08:00'],
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 2),
    );
    expect(short.occurrences(DateTime(2026, 11, 1), DateTime(2026, 11, 5)), [
      DateTime(2026, 11, 1, 8),
      DateTime(2026, 11, 2, 8),
    ]);
  });

  test('a banner "Time for your {name}" with Done / Later for the next two days', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final gateway = _Gateway();
    final scheduler = NotificationScheduler(
      gateway: gateway,
      database: db,
      strings: () => enStrings,
      clock: () => DateTime(2026, 11, 1, 6),
    );
    await scheduler.reconcilePersonalReminders([walk]);

    final rings = gateway.scheduled.values.toList()..sort((a, b) => a.at.compareTo(b.at));
    expect(rings.map((r) => r.at), [DateTime(2026, 11, 1, 7), DateTime(2026, 11, 1, 18)]);
    expect(rings.first.title, 'Time for your walk');
    expect(rings.first.body, '30 minutes after breakfast');
    expect(rings.first.style, ReminderStyle.banner);
    expect(rings.first.actions.map((a) => a.id), [reminderActionDone, reminderActionLater]);
    expect(rings.first.payload, contains('"byCaregiver":true'));

    // Removed: nothing left on the phone.
    await scheduler.reconcilePersonalReminders([]);
    expect(gateway.scheduled, isEmpty);
    await db.close();
  });
}
