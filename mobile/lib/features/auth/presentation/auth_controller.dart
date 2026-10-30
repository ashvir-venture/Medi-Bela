import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/result.dart';
import '../../../providers/core_providers.dart';
import '../../notices/presentation/notices_controller.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';
import 'session_notifier.dart';

/// `AsyncValue<UserModel?>`:
/// - loading → still determining session state on app start
/// - data(null) → confirmed logged out
/// - data(user) → logged in, [user] is best-known profile (cache-then-network)
/// - error → only used for the initial bootstrap failing unexpectedly
class AuthController extends StateNotifier<AsyncValue<UserModel?>> {
  AuthController(this._ref, this._repository)
      : super(const AsyncValue.loading()) {
    _bootstrap();
  }

  final Ref _ref;
  final AuthRepository _repository;

  Future<void> _bootstrap() async {
    final hasSession = await _repository.hasSession();
    if (!hasSession) {
      state = const AsyncValue.data(null);
      _ref.read(sessionNotifierProvider.notifier).setLoggedIn(false);
      return;
    }

    // Local-first: render the cached profile immediately.
    final cached = await _repository.getCachedUser();
    state = AsyncValue.data(cached);
    _ref.read(sessionNotifierProvider.notifier).setLoggedIn(true);

    // Then reconcile with the server in the background. If offline, the
    // cached value simply stays as-is — this is not an error state.
    final result = await _repository.refreshProfileFromServer();
    result.when(
      success: (user) => state = AsyncValue.data(user),
      failure: (_) {},
    );
  }

  /// Success is true when this login reactivated a deactivated account.
  Future<Result<bool>> login({
    required String phone,
    required String password,
  }) async {
    final result = await _repository.login(phone: phone, password: password);
    return result.when(
      success: (outcome) {
        final (user, reactivated) = outcome;
        _ref.read(sessionExpiredNoticeProvider.notifier).state = false;
        state = AsyncValue.data(user);
        _ref.read(sessionNotifierProvider.notifier).setLoggedIn(true);
        return Result.success(reactivated);
      },
      failure: (message) => Result.failure(message),
    );
  }

  Future<Result<UserModel>> register({
    required String phone,
    required String name,
    required String password,
    String? address,
    String? languagePreference,
    Map<String, dynamic> details = const {},
    required bool acceptTerms,
  }) async {
    final result = await _repository.register(
      acceptTerms: acceptTerms,
      phone: phone,
      name: name,
      password: password,
      address: address,
      languagePreference: languagePreference,
      details: details,
    );
    result.when(
      success: (user) {
        state = AsyncValue.data(user);
        _ref.read(sessionNotifierProvider.notifier).setLoggedIn(true);
      },
      failure: (_) {},
    );
    return result;
  }

  Future<void> logout() async {
    // Order matters. Push de-registration needs the access token, and local
    // reminders are tracked in tables the repository is about to wipe.
    //
    // Every cleanup step is best-effort and time-limited: a slow or offline
    // network, or a failing plugin, must never block or abort the logout.
    Future<void> bestEffort(String name, Future<void> Function() step) async {
      try {
        await step().timeout(const Duration(seconds: 5));
      } catch (e, st) {
        debugPrint('LOGOUT step "$name" failed: $e\n$st');
      }
    }

    await bestEffort('push', () => _ref.read(pushServiceProvider).onLogout());
    await bestEffort(
        'notifications', () => _ref.read(notificationSchedulerProvider).cancelAll());
    await bestEffort('notices', () => _ref.read(noticesCacheProvider).clear());
    try {
      await _repository.logout();
    } catch (e, st) {
      debugPrint('LOGOUT local wipe failed: $e\n$st');
    }
    debugPrint('LOGOUT finished, ending session');
    // End the session first so the router moves to the login screen at once,
    // then drop the in-memory user.
    _ref.read(sessionNotifierProvider.notifier).setLoggedIn(false);
    state = const AsyncValue.data(null);
  }

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _repository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  /// Deletes the account (server first, then this device). On success the
  /// session ends exactly like a logout; on failure nothing local changes.
  Future<Result<void>> deleteAccount({required String password}) async {
    await _syncFirst();
    final result = await _repository.deleteAccount(password: password);
    if (result.isSuccess) await _endAccountSession();
    return result;
  }

  /// Pauses the account (signing in again reactivates it). Same local
  /// cleanup as a delete.
  Future<Result<void>> deactivate({required String password}) async {
    await _syncFirst();
    final result = await _repository.deactivate(password: password);
    if (result.isSuccess) await _endAccountSession();
    return result;
  }

  /// Sends queued changes (doses taken offline...) before the account is
  /// paused or deleted, so nothing marked on this phone is lost. Best effort.
  Future<void> _syncFirst() async {
    try {
      await _ref.read(syncServiceProvider).drainQueue().timeout(const Duration(seconds: 15));
    } catch (_) {}
  }

  /// The server already dropped this device's push registration with the
  /// account; these are the local leftovers.
  Future<void> _endAccountSession() async {
    try {
      await _ref.read(pushServiceProvider).onLogout();
    } catch (_) {}
    await _ref.read(notificationSchedulerProvider).cancelAll();
    await _ref.read(noticesCacheProvider).clear();
    state = const AsyncValue.data(null);
    _ref.read(sessionNotifierProvider.notifier).setLoggedIn(false);
  }

  /// Re-pulls the profile from the server, keeping the local cache and
  /// visible state in sync. Safe to call opportunistically (e.g.
  /// pull-to-refresh) — silently keeps the cached value if offline.
  Future<void> refreshProfile() async {
    final result = await _repository.refreshProfileFromServer();
    result.when(success: (user) => state = AsyncValue.data(user), failure: (_) {});
  }

  Future<Result<UserModel>> updateProfile(Map<String, dynamic> patch) async {
    final result = await _repository.updateProfile(patch);
    result.when(
      success: (user) => state = AsyncValue.data(user),
      failure: (_) {},
    );
    return result;
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<UserModel?>>((ref) {
  return AuthController(ref, ref.watch(authRepositoryProvider));
});
