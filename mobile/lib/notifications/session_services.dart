import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_controller.dart';
import '../features/auth/domain/user_model.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../providers/core_providers.dart';
import 'reminder_timing.dart';
import '../core/constants/api_endpoints.dart';

/// Things that must be running for as long as someone is logged in,
/// independent of which screen is open:
///
///  1. Push registration (FCM token -> backend).
///  2. Local reminder upkeep. Medicine/health reminders are scheduled with the
///     OS from the local cache, so they fire offline. Previously they were only
///     (re)scheduled when the user happened to open the "Today's medicine"
///     screen, so a newly completed prescription produced no reminders until
///     then. Now they are reconciled at login, on every app resume, and
///     whenever connectivity returns.
///  3. Server data pulled on those same moments (login, reactivation, resume,
///     back online): doses, health reminders, prescriptions, health records,
///     personal reminders and the medicine box; and (owner, 2026-10-31) every
///     [periodicRefresh] while the app is open and online.
/// How often the server is asked again while the app is in front
/// (APP_SYNC_MINUTES on the server, default 10).
Duration get periodicRefresh => Duration(minutes: ReminderTiming.current.appSyncMinutes);

class SessionServices with WidgetsBindingObserver {
  SessionServices(this._ref);

  final Ref _ref;
  bool _running = false;
  bool _refreshing = false;
  Timer? _timer;
  StreamSubscription<bool>? _connectivitySub;
  ProviderSubscription<AsyncValue<UserModel?>>? _userSub;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub =
        _ref.read(connectivityServiceProvider).onStatusChange.listen((online) {
      if (online) unawaited(refresh());
    });
    // The account owns the medicine-reminders switch; mirror it locally and
    // reschedule (or cancel) reminders as soon as it changes.
    _userSub = _ref.listen<AsyncValue<UserModel?>>(
      authControllerProvider,
      (_, next) {
        final user = next.valueOrNull;
        if (user != null) unawaited(_applyReminderSwitch(user.medicineRemindersEnabled));
      },
      fireImmediately: true,
    );
    try {
      await _ref.read(pushServiceProvider).start();
    } catch (_) {/* push is optional */}
    _timer = Timer.periodic(periodicRefresh, (_) => unawaited(_periodic()));
    await refresh();
  }

  Future<void> _pullTimings() async {
    try {
      final response = await _ref.read(dioClientProvider).dio.get<Map<String, dynamic>>(ApiEndpoints.appConfig);
      final reminders = response.data?['reminders'];
      if (reminders is! Map<String, dynamic>) return;
      final syncBefore = ReminderTiming.current.appSyncMinutes;
      if (await ReminderTiming.apply(reminders)) {
        _ref.read(notificationSchedulerProvider).timingChanged();
        if (ReminderTiming.current.appSyncMinutes != syncBefore && _timer != null) {
          _timer!.cancel();
          _timer = Timer.periodic(periodicRefresh, (_) => unawaited(_periodic()));
        }
      }
    } catch (_) {/* offline: the saved values stay */}
  }

  /// Only while the app is in front and online (no battery spent in the background).
  Future<void> _periodic() async {
    if (!_running || WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    if (!await _ref.read(connectivityServiceProvider).isOnline) return;
    await refresh();
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    _userSub?.close();
    _userSub = null;
  }

  Future<void> _applyReminderSwitch(bool enabled) async {
    final changed = await _ref.read(reminderPreferenceProvider).set(enabled);
    if (changed) {
      await _ref.read(medicineScheduleRepositoryProvider).reconcileLocalNotifications();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _running) unawaited(refresh());
  }

  /// Language lives on the account too (push text is localized from it).
  /// A choice made on this device is uploaded; otherwise the account's saved
  /// preference is adopted, e.g. after logging in on a new phone.
  Future<void> _syncLanguagePreference() async {
    final auth = _ref.read(authControllerProvider.notifier);
    final user = _ref.read(authControllerProvider).value;
    if (user == null) return;
    final locale = _ref.read(localeControllerProvider.notifier);
    final local = _ref.read(localeControllerProvider).languageCode.toUpperCase();
    if (user.languageCode == local) {
      await locale.markSynced();
    } else if (await locale.hasUnsyncedChoice()) {
      final result = await auth.updateProfile({'languagePreference': local});
      result.when(success: (_) => locale.markSynced(), failure: (_) {});
    } else {
      await locale.setLanguage(user.languageCode.toLowerCase(), fromServer: true);
    }
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final medicine = _ref.read(medicineScheduleRepositoryProvider);
      final health = _ref.read(healthReminderRepositoryProvider);
      final personal = _ref.read(personalReminderRepositoryProvider);

      // 0. Reminder timings from the server's .env: a change reschedules everything.
      await _pullTimings();

      // 1. Offline-safe: make sure the OS has what the cache says it should.
      await medicine.reconcileLocalNotifications();
      await health.reconcileLocalNotifications();
      await personal.reconcileLocalNotifications();

      // 2. Then pull fresh data (each of these reconciles again on success).
      await medicine.refreshFromServer();
      await health.refreshFromServer();
      await personal.refreshFromServer();
      try {
        await _ref.read(medicineBoxRepositoryProvider).refreshFromServer();
      } catch (_) {/* kept for the next refresh */}
      // The rest of the offline copy: my prescriptions (restored after a
      // reinstall or sign-in on a new phone) and health records.
      await _ref.read(prescriptionLocalRepositoryProvider).refreshStatuses();
      try {
        await _ref.read(healthRecordRepositoryProvider).refreshFromServer();
      } catch (_) {/* kept for the next refresh */}
      await _ref.read(pushServiceProvider).retryRegistration();
      await _syncLanguagePreference();
    } catch (_) {
      // Never let background upkeep surface as an error to the user.
    } finally {
      _refreshing = false;
    }
  }
}

final sessionServicesProvider = Provider<SessionServices>((ref) {
  final services = SessionServices(ref);
  ref.onDispose(services.stop);
  return services;
});
