import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../notifications/local_notifications_gateway.dart' show androidChannelId;
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
    );
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
