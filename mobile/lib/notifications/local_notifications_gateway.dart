import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

const androidChannelId = 'medicine_reminders';
const androidChannelName = 'Medicine reminders';
const androidChannelDescription = 'Reminders for your scheduled medicine doses';

/// Everything `NotificationScheduler` needs from
/// `flutter_local_notifications`, narrowed to an interface so tests can
/// supply an in-memory fake instead of the real plugin (which talks to a
/// platform channel and can't run in a plain Dart test).
abstract class LocalNotificationsGateway {
  Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    DateTime scheduledAt,
  );
  Future<void> cancel(int id);
}

class FlutterLocalNotificationsGateway implements LocalNotificationsGateway {
  FlutterLocalNotificationsGateway(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> zonedSchedule(
    int id,
    String title,
    String body,
    DateTime scheduledAt,
  ) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          androidChannelId,
          androidChannelName,
          channelDescription: androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);
}
