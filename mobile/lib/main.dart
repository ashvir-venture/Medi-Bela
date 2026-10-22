import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'app.dart';
import 'notifications/push_service.dart' show localNotificationTaps;

import 'package:flutter/foundation.dart';

/// Shared plugin instance for scheduling on-device reminders (medicine
/// times, health check-ins). Initialized once at startup and used by
/// `NotificationScheduler` (see lib/notifications/).
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> _initLocalNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    // Taps on notifications the app displayed itself (e.g. a push that arrived
    // while the app was open) are routed by PushService.
    onDidReceiveNotificationResponse: (response) =>
        localNotificationTaps.add(response.payload),
  );

  // Android 13+ and iOS both require an explicit runtime permission
  // request before a scheduled notification will actually show.
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >()
      ?.requestPermissions(alert: true, badge: true, sound: true);
}

void _initTimeZones() {
  tz_data.initializeTimeZones();
  // ASSUMPTION: single-timezone deployment (Bangladesh). Without a
  // device-timezone-name plugin (not currently a dependency), there's no
  // reliable way to read the phone's actual IANA zone from pure Dart —
  // see NotificationScheduler's doc comment. Revisit if the app ever
  // needs to support users outside Asia/Dhaka.
  tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Push notifications are optional; local reminders must still work
  // if Firebase initialization fails.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  _initTimeZones();
  await _initLocalNotifications();

  runApp(const ProviderScope(child: CareBridgeApp()));
}
