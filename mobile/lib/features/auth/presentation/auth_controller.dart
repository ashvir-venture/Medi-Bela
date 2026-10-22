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

  Future<Result<UserModel>> login({
    required String phone,
    required String password,
  }) async {
    final result = await _repository.login(phone: phone, password: password);
    result.when(
      success: (user) {
        state = AsyncValue.data(user);
        _ref.read(sessionNotifierProvider.notifier).setLoggedIn(true);
      },
      failure: (_) {},
    );
    return result;
  }

  Future<Result<UserModel>> register({
    required String phone,
    required String name,
    required String password,
    String? address,
    String? languagePreference,
  }) async {
    final result = await _repository.register(
      phone: phone,
      name: name,
      password: password,
      address: address,
      languagePreference: languagePreference,
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
    await _ref.read(pushServiceProvider).onLogout();
    await _ref.read(notificationSchedulerProvider).cancelAll();
    await _ref.read(noticesCacheProvider).clear();
    await _repository.logout();
    state = const AsyncValue.data(null);
    _ref.read(sessionNotifierProvider.notifier).setLoggedIn(false);
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
    final result = await _repository.deleteAccount(password: password);
    if (!result.isSuccess) return result;
    // The server already dropped this device's push registration with the
    // account; these are the local leftovers.
    try {
      await _ref.read(pushServiceProvider).onLogout();
    } catch (_) {}
    await _ref.read(notificationSchedulerProvider).cancelAll();
    await _ref.read(noticesCacheProvider).clear();
    state = const AsyncValue.data(null);
    _ref.read(sessionNotifierProvider.notifier).setLoggedIn(false);
    return result;
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
