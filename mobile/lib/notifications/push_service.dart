import 'dart:async';
import 'dart:convert';

import '../firebase_options.dart';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/api_endpoints.dart';
import '../core/storage/secure_storage_service.dart';
import '../features/auth/data/device_session_wipe.dart';
import 'reminder_actions.dart' show backstopTime;

/// Android channel used for every server-generated (FCM) notification. Must
/// match `ANDROID_CHANNEL_ID` in the backend's push.service.ts.
const alertsChannelId = 'carebridge_alerts';
const _alertsChannelName = 'Medi-Bela alerts';

/// Receives taps on notifications that this app displayed itself (foreground
/// FCM messages shown through flutter_local_notifications). Wired up in
/// `main.dart` via `onDidReceiveNotificationResponse`.
final StreamController<String?> localNotificationTaps =
    StreamController<String?>.broadcast();

/// Pure mapping from an FCM `data` payload to an in-app route. Kept free of
/// Firebase types so it can be unit tested.
///
/// The payload carries only routing ids — never medicine names or doses —
/// so everything sensitive is fetched through authenticated, family-scoped
/// API calls after the user opens the app.
String routeForNotificationData(Map<String, dynamic> data) {
  switch (data['type']) {
    case 'MISSED_DOSE_FAMILY_ALERT':
      final member = data['memberUserId'];
      return member is String && member.isNotEmpty
          ? '/family/member/$member'
          : '/family';
    case 'PRESCRIPTION_UPDATE':
      // A member's prescription, sent to their caregiver (Round 13).
      final member = data['memberUserId'];
      return member is String && member.isNotEmpty ? '/family/member/$member/prescriptions' : '/prescription';
    case 'NOTICE':
      final noticeId = data['noticeId'];
      return noticeId is String ? '/notices?id=$noticeId' : '/notices';
    case 'MEDICINE_REMINDER':
      // Local reminders (at = ms) and the server's backstop (scheduledAt) open
      // that time's reminder page; names are only in the app.
      final at = data['at'];
      final scheduledAt = data['scheduledAt'];
      final ms = at is int
          ? at
          : scheduledAt is String
              ? DateTime.tryParse(scheduledAt)?.millisecondsSinceEpoch
              : null;
      if (ms == null) return '/medicines?tab=today';
      final stage = data['stage'] is int ? data['stage'] as int : (data['kind'] == 'backstop' ? 1 : 0);
      return '/reminder?at=$ms&stage=$stage';
    case 'MEDICINE_BOX':
      final routine = data['routineId'];
      if (routine is String && data['kind'] == 'empty') return '/medicine-box/empty?routine=$routine';
      if (routine is String && data['kind'] == 'refill') return '/medicine-box/refill?routine=$routine';
      return '/medicine-box';
    case 'PERSONAL_REMINDER':
      return '/health/personal-reminders';
    case 'CARE_REMINDER':
      // Round 15-16: visit / test / session / pen reminders open their page.
      final route = data['route'];
      return route is String && route.startsWith('/health') ? route : '/health/records';
    case 'TEST_REMINDER':
      final id = data['reminderId'];
      final day = data['day'] is int ? data['day'] as int : 0;
      return id is String ? '/test-reminder/$id?day=$day' : '/health/reminders';
    case 'SYSTEM':
      final member = data['memberUserId'];
      switch (data['kind']) {
        case 'family_invitation':
          return '/family';
        // Round 17: a notice someone in the family shared.
        case 'notice_shared':
          final noticeId = data['noticeId'];
          return noticeId is String ? '/notices?id=$noticeId' : '/notices';
        case 'medicine_box_empty':
          return member is String ? '/medicine-box?for=$member' : '/inbox';
        case 'personal_reminder_later':
          return member is String ? '/family/member/$member' : '/inbox';
        // Round 15: a member's reading out of range, or their "Alert family".
        case 'reading_alert':
        case 'help_alert':
          return member is String ? '/family/member/$member' : '/family';
      }
      return '/inbox';
    default:
      return '/inbox';
  }
}

/// The route a ringing reminder opens as a full screen (only its buttons
/// close it: `alarm=1`), or null for other notifications.
String? alarmRouteForPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final data = Map<String, dynamic>.from(jsonDecode(payload) as Map);
    final type = data['type'];
    final ringing = type == 'MEDICINE_REMINDER' ||
        type == 'TEST_REMINDER' ||
        (type == 'MEDICINE_BOX' && data['kind'] == 'empty');
    if (!ringing) return null;
    final route = routeForNotificationData(data);
    return route.contains('?') ? '$route&alarm=1' : '$route?alarm=1';
  } catch (_) {
    return null;
  }
}

/// Owns the device's FCM lifecycle:
///  - ask permission, create the Android channel
///  - register the token with the backend (and again whenever FCM rotates it,
///    telling the backend which token it replaces)
///  - show messages that arrive while the app is open
///  - route taps to the right screen
///  - on logout: unregister the token AND delete it at FCM, so a shared or
///    handed-over phone can't keep receiving the previous user's alerts —
///    even when the unregister call can't reach the server (offline).
///
/// Everything here is best-effort and must never break the app: push is an
/// enhancement on top of the offline-first local reminders, so a missing
/// Firebase config, denied permission or no network just means no push.
class PushService {
  PushService({
    required Dio dio,
    required SecureStorageService secureStorage,
    required FlutterLocalNotificationsPlugin localPlugin,
    required void Function(String route) navigate,
    Future<void> Function(DateTime scheduledAt)? onReminderBackstop,
    Future<void> Function()? onSessionEnded,
    Future<void> Function(Map<String, dynamic> data)? onCaregiverAction,
  }) : _dio = dio,
       _storage = secureStorage,
       _local = localPlugin,
       _navigate = navigate,
       _onReminderBackstop = onReminderBackstop,
       _onSessionEnded = onSessionEnded,
       _onCaregiverAction = onCaregiverAction;

  final Dio _dio;
  final SecureStorageService _storage;
  final FlutterLocalNotificationsPlugin _local;
  final void Function(String route) _navigate;
  final Future<void> Function(DateTime scheduledAt)? _onReminderBackstop;
  /// The account was paused or removed on the server (data-only push).
  final Future<void> Function()? _onSessionEnded;
  /// Round 14: the caregiver gave a dose ("I gave it") or switched easy mode:
  /// pull the change so the phone stops ringing / shows the right Home.
  final Future<void> Function(Map<String, dynamic> data)? _onCaregiverAction;

  final List<StreamSubscription<dynamic>> _subs = [];
  bool _firebaseReady = false;
  bool _started = false;
  String? _currentToken;
  bool _registrationPending = false;

  Future<bool> _ensureFirebase() async {
    if (_firebaseReady) return true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      _firebaseReady = true;
    } catch (e) {
      debugPrint('Push disabled: Firebase not configured ($e)');
    }

    return _firebaseReady;
  }

  bool _localStarted = false;
  static const _alarmChannel = MethodChannel('com.carebridge.app/reminder_status');
  bool _launchHandled = false;

  /// Taps on the app's own notifications (medicine / test reminders, and
  /// pushes shown while open), with or without Firebase. A tap that started
  /// the app from closed is read from the plugin's launch details.
  Future<void> _startLocalTaps() async {
    if (_localStarted) return;
    _localStarted = true;
    _subs.add(
      localNotificationTaps.stream.listen((payload) {
        if (payload == null || payload.isEmpty) return;
        try {
          _handleTap(Map<String, dynamic>.from(jsonDecode(payload) as Map));
        } catch (_) {}
      }),
    );
    // Full-screen reminders opened by Android over other apps (FullScreenAlarms.kt).
    if (defaultTargetPlatform == TargetPlatform.android) {
      _alarmChannel.setMethodCallHandler((call) async {
        if (call.method == 'openRoute' && call.arguments is String) _navigate(call.arguments as String);
        return null;
      });
    }
    if (_launchHandled) return;
    _launchHandled = true;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final route = await _alarmChannel.invokeMethod<String>('takeLaunchRoute');
        if (route != null) {
          _navigate(route);
          return;
        }
      }
    } catch (_) {}
    try {
      final launch = await _local.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      final payload = response?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) &&
          response?.actionId == null &&
          payload != null &&
          payload.isNotEmpty) {
        _handleTap(Map<String, dynamic>.from(jsonDecode(payload) as Map));
      }
    } catch (_) {}
  }

  /// Call once the user is logged in. Safe to call repeatedly.
  Future<void> start() async {
    await _startLocalTaps();
    if (_started) {
      await retryRegistration();
      return;
    }
    if (!await _ensureFirebase()) return;
    _started = true;

    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission();
    } catch (_) {
      /* denied/unsupported: local reminders still work */
    }

    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            alertsChannelId,
            _alertsChannelName,
            importance: Importance.high,
          ),
        );

    _subs.add(
      messaging.onTokenRefresh.listen(
        (token) => _register(token, previous: _currentToken),
        onError: (_) {},
      ),
    );
    _subs.add(FirebaseMessaging.onMessage.listen(_showForeground));
    _subs.add(
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleTap(m.data)),
    );
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleTap(initial.data);

    String? token;
    try {
      token = await messaging.getToken();
    } catch (_) {}
    if (token != null) await _register(token, previous: null);
  }

  /// Re-attempts a registration that failed (e.g. was offline). Cheap no-op
  /// when nothing is pending; call on connectivity regained / app resume.
  Future<void> retryRegistration() async {
    if (!_registrationPending || !_firebaseReady) return;
    final token = _currentToken;
    if (token != null) await _register(token, previous: null);
  }

  Future<void> _register(String token, {String? previous}) async {
    _currentToken = token;
    final lastRegistered = await _storage.readRegisteredPushToken();
    try {
      await _dio.post<void>(
        ApiEndpoints.registerDevice,
        data: {
          'token': token,
          'platform': defaultTargetPlatform == TargetPlatform.iOS
              ? 'IOS'
              : 'ANDROID',
          // On rotation, name the token being replaced so the backend drops it.
          if ((previous ?? lastRegistered) != null &&
              (previous ?? lastRegistered) != token)
            'previousToken': previous ?? lastRegistered,
        },
      );
      await _storage.saveRegisteredPushToken(token);
      _registrationPending = false;
    } catch (_) {
      _registrationPending = true; // retried later; never surfaced to the user
    }
  }

  Future<void> _showForeground(RemoteMessage message) async {
    // The account was deactivated, deleted or banned: end the session here.
    if (isSessionEndedMessage(message.data)) {
      await _onSessionEnded?.call();
      return;
    }
    // Data-only reminder backstop: shown only if those doses are still
    // untaken in the local database (see NotificationScheduler.showBackstop).
    final backstopAt = backstopTime(message.data);
    if (backstopAt != null) {
      await _onReminderBackstop?.call(backstopAt);
      return;
    }
    if (isCaregiverActionMessage(message.data)) {
      try {
        await _onCaregiverAction?.call(message.data);
      } catch (_) {/* shown anyway; the next refresh catches up */}
    }
    final n = message.notification;
    if (n == null) return;
    try {
      await _local.show(
        (message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}')
                .hashCode &
            0x7FFFFFFF,
        n.title,
        n.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            alertsChannelId,
            _alertsChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (_) {}
  }

  void _handleTap(Map<String, dynamic> data) {
    final id = data['notificationId'];
    if (id is String && id.isNotEmpty) {
      // Best-effort: opening the notification marks it read.
      unawaited(
        _dio
            .post<void>(ApiEndpoints.notificationRead(id))
            .then((_) {}, onError: (_) {}),
      );
    }
    // A reminder opens its page in alarm mode: only Taken / Later close it.
    _navigate(alarmRouteForPayload(jsonEncode(data)) ?? routeForNotificationData(data));
  }

  /// Must run BEFORE session tokens are cleared (the unregister call is
  /// authenticated). Never throws.
  Future<void> onLogout() async {
    final registered = await _storage.readRegisteredPushToken();
    final token = registered ?? _currentToken;
    if (token != null) {
      try {
        await _dio.post<void>(
          ApiEndpoints.unregisterDevice,
          data: {'token': token},
        );
      } catch (_) {
        /* covered by deleteToken() below */
      }
    }
    await _storage.clearRegisteredPushToken();

    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    _started = false;
    _localStarted = false;
    _currentToken = null;
    _registrationPending = false;

    if (_firebaseReady) {
      try {
        // Invalidates the token at FCM itself: even if the server still has
        // it (offline logout), pushes to it now fail and the server prunes it.
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
  }
}

/// A "your caregiver did something" push (data.kind caregiver_action).
bool isCaregiverActionMessage(Map<String, dynamic> data) => data['kind'] == 'caregiver_action';
