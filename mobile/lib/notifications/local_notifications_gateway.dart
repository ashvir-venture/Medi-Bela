import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Quiet/plain reminders (health reminders, the silent re-post of a medicine
/// reminder once it has stopped ringing).
const androidChannelId = 'medicine_reminders';
const androidChannelName = 'Medicine reminders';
const androidChannelDescription = 'Reminders for your scheduled medicine doses';

/// Medicine reminders while they ring: the phone's alarm tone, repeating
/// (FLAG_INSISTENT) until touched, removed after [ringDuration] and replaced
/// by a silent copy. Uses the notification audio stream, so it respects
/// silent/vibrate. Channel sound can't change after creation: a new sound
/// needs a new channel id.
const alarmChannelId = 'medicine_alarm';
const alarmChannelName = 'Medicine alarm';
const alarmChannelDescription = 'Rings when it is time to take your medicine';

const ringDuration = Duration(minutes: 2);

/// Action ids on medicine reminders (see reminder_actions.dart).
const reminderActionDone = 'done';
const reminderActionLater = 'later';

/// How a scheduled notification presents itself.
enum ReminderStyle {
  /// A normal notification (health reminders).
  plain,

  /// A medicine reminder that rings with the alarm tone for [ringDuration].
  ringing,

  /// The silent copy shown after the ringing one is removed.
  quiet,
}

class ReminderAction {
  const ReminderAction(this.id, this.label);
  final String id;
  final String label;
}

/// One notification to schedule. Text must stay neutral (no medicine names):
/// it shows on the lock screen and many phones are shared.
class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    this.style = ReminderStyle.plain,
    this.payload,
    this.actions = const [],
  });

  final int id;
  final String title;
  final String body;
  final DateTime at;
  final ReminderStyle style;
  final String? payload;
  final List<ReminderAction> actions;
}

/// Everything `NotificationScheduler` needs from
/// `flutter_local_notifications`, narrowed to an interface so tests can
/// supply an in-memory fake instead of the real plugin (which talks to a
/// platform channel and can't run in a plain Dart test).
abstract class LocalNotificationsGateway {
  /// [exact] uses an exact alarm (fires on time, even in Doze). Without it
  /// the OS may batch the alarm and deliver it late.
  Future<void> schedule(ScheduledReminder reminder, {required bool exact});

  /// Shows [reminder] now (its `at` is ignored).
  Future<void> show(ScheduledReminder reminder);

  Future<void> cancel(int id);

  /// Whether exact alarms are allowed (Android 12+ "Alarms & reminders").
  /// Always true where the OS has no such permission.
  Future<bool> canScheduleExact();
}

class FlutterLocalNotificationsGateway implements LocalNotificationsGateway {
  FlutterLocalNotificationsGateway(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  // Android FLAG_INSISTENT: repeat the sound until the notification is
  // touched, cancelled or the shade is opened.
  static final _insistent = Int32List.fromList([4]);

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> schedule(ScheduledReminder reminder, {required bool exact}) async {
    // iOS has no silent re-post: one notification per reminder is enough.
    if (reminder.style == ReminderStyle.quiet && !_isAndroid) return;
    await _plugin.zonedSchedule(
      reminder.id,
      reminder.title,
      reminder.body,
      tz.TZDateTime.from(reminder.at, tz.local),
      _details(reminder),
      payload: reminder.payload,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> show(ScheduledReminder reminder) => _plugin.show(
        reminder.id,
        reminder.title,
        reminder.body,
        _details(reminder),
        payload: reminder.payload,
      );

  NotificationDetails _details(ScheduledReminder reminder) {
    final actions = [
      for (final a in reminder.actions)
        AndroidNotificationAction(a.id, a.label, cancelNotification: true),
    ];
    final android = switch (reminder.style) {
      ReminderStyle.ringing => AndroidNotificationDetails(
          alarmChannelId,
          alarmChannelName,
          channelDescription: alarmChannelDescription,
          importance: Importance.max,
          priority: Priority.max,
          sound: const UriAndroidNotificationSound('content://settings/system/alarm_alert'),
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          additionalFlags: _insistent,
          timeoutAfter: ringDuration.inMilliseconds,
          actions: actions,
        ),
      ReminderStyle.quiet => AndroidNotificationDetails(
          androidChannelId,
          androidChannelName,
          channelDescription: androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          silent: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          actions: actions,
        ),
      ReminderStyle.plain => const AndroidNotificationDetails(
          androidChannelId,
          androidChannelName,
          channelDescription: androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
    };
    return NotificationDetails(android: android, iOS: const DarwinNotificationDetails());
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<bool> canScheduleExact() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }
}
