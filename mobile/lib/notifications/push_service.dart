import 'dart:async';
import 'dart:convert';

import '../firebase_options.dart';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/constants/api_endpoints.dart';
import '../core/storage/secure_storage_service.dart';
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
      return '/prescription';
    case 'NOTICE':
      final noticeId = data['noticeId'];
      return noticeId is String ? '/notices?id=$noticeId' : '/notices';
    case 'MEDICINE_REMINDER':
      // Local reminders and the server's backstop: names are only in the app.
      return '/prescription/today';
    case 'SYSTEM':
      return data['kind'] == 'family_invitation' ? '/family' : '/inbox';
    default:
      return '/inbox';
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
  }) : _dio = dio,
       _storage = secureStorage,
       _local = localPlugin,
       _navigate = navigate,
       _onReminderBackstop = onReminderBackstop;

  final Dio _dio;
  final SecureStorageService _storage;
  final FlutterLocalNotificationsPlugin _local;
  final void Function(String route) _navigate;
  final Future<void> Function(DateTime scheduledAt)? _onReminderBackstop;

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

  /// Call once the user is logged in. Safe to call repeatedly.
  Future<void> start() async {
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
    _subs.add(
      localNotificationTaps.stream.listen((payload) {
        if (payload == null || payload.isEmpty) return;
        try {
          _handleTap(Map<String, dynamic>.from(jsonDecode(payload) as Map));
        } catch (_) {}
      }),
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
    // Data-only reminder backstop: shown only if those doses are still
    // untaken in the local database (see NotificationScheduler.showBackstop).
    final backstopAt = backstopTime(message.data);
    if (backstopAt != null) {
      await _onReminderBackstop?.call(backstopAt);
      return;
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
    _navigate(routeForNotificationData(data));
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
