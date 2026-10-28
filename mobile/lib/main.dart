import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'notifications/push_service.dart' show localNotificationTaps;
import 'notifications/reminder_actions.dart';
import 'notifications/reminder_preference.dart';
import 'providers/core_providers.dart';

/// Shared plugin instance for scheduling on-device reminders (medicine
/// times, health check-ins). Initialized once at startup and used by
/// `NotificationScheduler` (see lib/notifications/).
final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> _initLocalNotifications(ProviderContainer container) async {
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (response) {
      // Done / Later tapped while the app is running: same handler as the
      // background isolate, with the app's own services.
      if (isReminderAction(response)) {
        handleReminderAction(container, response);
        return;
      }
      // Taps on notifications the app displayed itself (reminders, or a push
      // that arrived while the app was open) are routed by PushService.
      localNotificationTaps.add(response.payload);
    },
    onDidReceiveBackgroundNotificationResponse: reminderActionBackground,
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Push notifications are optional; local reminders must still work
  // if Firebase initialization fails.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  initTimeZones();
  final reminders = ReminderPreference();
  await reminders.load();
  final container = ProviderContainer(
    overrides: [reminderPreferenceProvider.overrideWithValue(reminders)],
  );
  await _initLocalNotifications(container);

  runApp(UncontrolledProviderScope(container: container, child: const CareBridgeApp()));
}
