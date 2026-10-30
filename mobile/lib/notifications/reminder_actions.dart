import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/constants/app_config.dart';
import '../core/localization/app_strings.dart';
import '../core/localization/locale_controller.dart';
import '../features/auth/data/device_session_wipe.dart';
import '../features/notices/presentation/notices_controller.dart';
import '../firebase_options.dart';
import '../main.dart' show flutterLocalNotificationsPlugin;
import '../providers/core_providers.dart';
import 'local_notifications_gateway.dart';
import 'notification_scheduler.dart';
import 'reminder_preference.dart';

/// Done / Later on a medicine reminder, and the server's backstop push.
///
/// These run with the app open, in the background, or after it was swiped
/// away (Android then starts a background isolate with no UI and no
/// ProviderScope). Every path works from the local database first, so it
/// works offline; Done then tries to send right away, because the app may
/// stay closed until the server's missed-dose cutoff.

const initializationSettings = InitializationSettings(
  android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  iOS: DarwinInitializationSettings(),
);

/// ASSUMPTION: single-timezone deployment (Bangladesh). Without a
/// device-timezone-name plugin (not currently a dependency), there's no
/// reliable way to read the phone's actual IANA zone from pure Dart.
/// Revisit if the app ever needs to support users outside Asia/Dhaka.
void initTimeZones() {
  tz_data.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
}

/// Decoded reminder payload (see [reminderPayload]).
class ReminderPayload {
  const ReminderPayload(this.at, this.stage);
  final DateTime at;
  final int stage;

  static ReminderPayload? tryParse(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final map = jsonDecode(payload) as Map<String, dynamic>;
      if (map['type'] != medicineReminderType) return null;
      return ReminderPayload(
        DateTime.fromMillisecondsSinceEpoch(map['at'] as int),
        map['stage'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}

bool isReminderAction(NotificationResponse response) =>
    response.actionId == reminderActionDone || response.actionId == reminderActionLater;

/// Applies Done / Later using [container]'s services.
Future<void> handleReminderAction(ProviderContainer container, NotificationResponse response) async {
  final payload = ReminderPayload.tryParse(response.payload);
  if (payload == null) return;
  final scheduler = container.read(notificationSchedulerProvider);

  if (response.actionId == reminderActionLater) {
    await scheduler.snooze(payload.at, payload.stage);
    return;
  }
  if (response.actionId != reminderActionDone) return;

  // Done marks every untaken dose of this time taken (decision: grouped).
  final repository = container.read(medicineScheduleRepositoryProvider);
  for (final doseId in await scheduler.pendingDoseIdsAt(payload.at)) {
    await repository.markDoseTaken(doseId);
  }
  await scheduler.reconcileFromCache();
  await container.read(syncServiceProvider).drainQueue();
}

/// Entry point for actions tapped while no UI isolate is handling them.
@pragma('vm:entry-point')
Future<void> reminderActionBackground(NotificationResponse response) async {
  if (!isReminderAction(response)) return;
  final container = await openBackgroundContainer();
  try {
    await handleReminderAction(container, response);
  } finally {
    container.dispose();
  }
}

/// FCM handler for data-only messages that arrive while the app is in the
/// background or closed: the medicine-reminder backstop (shown as the
/// group's second reminder, or dropped when the local database already shows
/// those doses taken) and "session ended" (the account was deactivated,
/// deleted or banned: reminders are cancelled and this phone's data wiped).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  if (isSessionEndedMessage(message.data)) {
    final container = await openBackgroundContainer();
    try {
      await wipeDeviceSession(
        cancelReminders: () => container.read(notificationSchedulerProvider).cancelAll(),
        storage: container.read(secureStorageProvider),
        database: container.read(appDatabaseProvider),
        clearNotices: () => container.read(noticesCacheProvider).clear(),
      );
    } finally {
      container.dispose();
    }
    return;
  }
  final at = backstopTime(message.data);
  if (at == null) return;
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  final container = await openBackgroundContainer();
  try {
    await container.read(notificationSchedulerProvider).showBackstop(at);
  } finally {
    container.dispose();
  }
}

/// The scheduled time a backstop push refers to, or null for other messages.
DateTime? backstopTime(Map<String, dynamic> data) {
  if (data['type'] != medicineReminderType || data['kind'] != 'backstop') return null;
  final raw = data['scheduledAt'];
  return raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
}

/// Services for a background isolate: same providers as the app, with the
/// language and reminder switch read from SharedPreferences up front.
Future<ProviderContainer> openBackgroundContainer() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  initTimeZones();
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  final prefs = await SharedPreferences.getInstance();
  final AppStrings strings =
      prefs.getString(PrefsKeys.languageCode) == 'bn' ? bnStrings : enStrings;
  final reminders = ReminderPreference();
  await reminders.load();

  return ProviderContainer(
    overrides: [
      stringsProvider.overrideWithValue(strings),
      reminderPreferenceProvider.overrideWithValue(reminders),
    ],
  );
}
