import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_controller.dart';
import '../features/auth/domain/user_model.dart';
import '../features/auth/presentation/auth_controller.dart';
import '../providers/core_providers.dart';

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
class SessionServices with WidgetsBindingObserver {
  SessionServices(this._ref);

  final Ref _ref;
  bool _running = false;
  bool _refreshing = false;
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
    await refresh();
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    WidgetsBinding.instance.removeObserver(this);
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

      // 1. Offline-safe: make sure the OS has what the cache says it should.
      await medicine.reconcileLocalNotifications();
      await health.reconcileLocalNotifications();

      // 2. Then pull fresh data (each of these reconciles again on success).
      await medicine.refreshFromServer();
      await health.refreshFromServer();
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
