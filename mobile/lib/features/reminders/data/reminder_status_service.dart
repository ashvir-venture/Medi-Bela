import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../notifications/local_notifications_gateway.dart'
    show alarmChannelId, alarmChannelName, alarmChannelDescription, androidChannelId;
import '../domain/reminder_status.dart';

/// Reads and requests the phone settings reminders depend on. Uses the
/// notifications plugin where it has an API, and a small channel in
/// MainActivity for the rest (channel blocked, battery optimization, opening
/// system settings). Non-Android platforms report [ReminderStatus.allOk].
class ReminderStatusService {
  ReminderStatusService(this._plugin);

  static const _channel = MethodChannel('com.carebridge.app/reminder_status');

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => defaultTargetPlatform ==
          TargetPlatform.android
      ? _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      : null;

  Future<ReminderStatus> check() async {
    final android = _android;
    if (android == null) return ReminderStatus.allOk;
    final appEnabled = await android.areNotificationsEnabled() ?? true;
    final channelBlocked = await _call<bool>(
          'isChannelBlocked',
          {'channelId': androidChannelId},
        ) ??
        false;
    return ReminderStatus(
      notificationsAllowed: appEnabled && !channelBlocked,
      exactAlarmsAllowed: await android.canScheduleExactNotifications() ?? false,
      batteryUnrestricted: await _call<bool>('isIgnoringBatteryOptimizations') ?? true,
      overlayAllowed: await _call<bool>('canDrawOverlays') ?? true,
      fullScreenAllowed: await _call<bool>('canUseFullScreenIntent') ?? true,
    );
  }

  /// "Display over other apps" for this app (a system page; the user turns it on).
  Future<void> requestOverlay() async {
    if (_android == null) return;
    await _call<bool>('openOverlaySettings');
  }

  /// Android 14+ page for full-screen notifications.
  Future<void> requestFullScreen() async {
    await _android?.requestFullScreenIntentPermission();
  }

  /// Shows the system prompt; once the user has refused it Android stops
  /// showing it, so fall back to the app's notification settings page.
  Future<void> requestNotifications() async {
    final android = _android;
    if (android == null) return;
    final granted = await android.requestNotificationsPermission() ?? false;
    final channelBlocked = await _call<bool>(
          'isChannelBlocked',
          {'channelId': androidChannelId},
        ) ??
        false;
    if (!granted || channelBlocked) await _call<bool>('openNotificationSettings');
  }

  /// Opens the "Alarms & reminders" page for this app.
  Future<void> requestExactAlarms() async {
    await _android?.requestExactAlarmsPermission();
  }

  /// Settings -> Reminder sound: Android's own page for the medicine alarm
  /// channel, where any ringtone can be picked. Until then it keeps today's
  /// sound (the phone's alarm tone); the channel is created first with it.
  Future<void> openReminderSoundSettings() async {
    final android = _android;
    if (android == null) return;
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        alarmChannelId,
        alarmChannelName,
        description: alarmChannelDescription,
        importance: Importance.max,
        sound: UriAndroidNotificationSound('content://settings/system/alarm_alert'),
      ),
    );
    await _call<bool>('openChannelSettings', {'channelId': alarmChannelId});
  }

  Future<void> openBatterySettings() async {
    if (_android == null) return;
    await _call<bool>('openBatterySettings');
  }

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
