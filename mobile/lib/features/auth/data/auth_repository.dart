import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/result.dart';
import '../data/auth_api.dart';
import '../domain/auth_tokens.dart';
import '../domain/user_model.dart';

/// The single source of truth for "who is logged in".
///
/// Tokens live only in [SecureStorageService]. The user's profile is
/// additionally cached in Drift (`CachedUsers`) purely so `/profile` and
/// other screens can render the user's name/phone instantly on cold start,
/// before the network round-trip to `/users/me` completes — consistent
/// with the app-wide "local read first, refresh from network" rule.
class AuthRepository {
  AuthRepository({
    required AuthApi api,
    required SecureStorageService secureStorage,
    required AppDatabase database,
  })  : _api = api,
        _secureStorage = secureStorage,
        _db = database;

  final AuthApi _api;
  final SecureStorageService _secureStorage;
  final AppDatabase _db;

  Future<bool> hasSession() => _secureStorage.hasSession();

  Future<Result<UserModel>> register({
    required String phone,
    required String name,
    required String password,
    String? address,
    String? languagePreference,
  }) async {
    try {
      final (user, tokens) = await _api.register(
        phone: phone,
        name: name,
        password: password,
        address: address,
        languagePreference: languagePreference,
      );
      await _persistSession(user, tokens);
      return Result.success(user);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<UserModel>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final (user, tokens) = await _api.login(phone: phone, password: password);
      await _persistSession(user, tokens);
      return Result.success(user);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<void> logout() async {
    try {
      // Don't wait on a slow server: after 5s just forget the session locally.
      await _api.logout().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Best-effort: even if the server call fails (e.g. offline), the
      // device must still forget the session.
    }
    await _secureStorage.clearTokens();
    // Everything per-user, not just the profile row: family members, doses,
    // reminders, health records, prescription drafts AND the outbox (which
    // would otherwise be replayed under the NEXT user's credentials).
    await _db.clearAllUserData();
  }

  /// Local-first read: cached profile, immediately, no network wait.
  Future<UserModel?> getCachedUser() async {
    final row = await _db.select(_db.cachedUsers).getSingleOrNull();
    return row == null ? null : _rowToModel(row);
  }

  /// Live-updating cached profile, for widgets that should reflect edits
  /// made elsewhere in the app without a manual refresh.
  Stream<UserModel?> watchCachedUser() {
    return _db.select(_db.cachedUsers).watchSingleOrNull().map(
          (row) => row == null ? null : _rowToModel(row),
        );
  }

  Future<Result<UserModel>> refreshProfileFromServer() async {
    try {
      final user = await _api.getMe();
      await _cacheUser(user);
      return Result.success(user);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<UserModel>> updateProfile(Map<String, dynamic> patch) async {
    try {
      final user = await _api.updateMe(patch);
      await _cacheUser(user);
      return Result.success(user);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<void>> forgotPassword({required String phone}) async {
    try {
      await _api.forgotPassword(phone: phone);
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  Future<Result<void>> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _api.resetPassword(phone: phone, code: code, newPassword: newPassword);
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
  }

  /// Deletes the account on the server; only if that succeeded, forgets the
  /// session and wipes everything stored for this user on the device.
  Future<Result<void>> deleteAccount({required String password}) async {
    try {
      await _api.deleteAccount(password: password);
    } on DioException catch (e) {
      return Result.failure(friendlyErrorMessage(e));
    }
    await _secureStorage.clearTokens();
    await _db.clearAllUserData();
    return const Result.success(null);
  }

  Future<void> _persistSession(UserModel user, AuthTokens tokens) async {
    // Safety net for paths that skipped logout (session expired, app data
    // from an older build): never carry one account's cache into another's.
    final previous = await _db.select(_db.cachedUsers).getSingleOrNull();
    if (previous != null && previous.id != user.id) {
      await _db.clearAllUserData();
    }
    await _secureStorage.saveTokens(accessToken: tokens.accessToken);
    await _cacheUser(user);
  }

  /// Only ever one row: this table caches "the current device's logged-in
  /// user", not a general user directory. Clearing before insert avoids
  /// ever ending up with a stale row from a previous account on the same
  /// device (e.g. after a force-close that skipped `logout()`).
  Future<void> _cacheUser(UserModel user) async {
    await _db.transaction(() async {
      await _db.delete(_db.cachedUsers).go();
      await _db.into(_db.cachedUsers).insert(
            CachedUsersCompanion.insert(
              id: user.id,
              phone: user.phone,
              name: user.name,
              address: Value(user.address),
              role: user.role,
              languageCode: Value(user.languageCode),
              notificationsEnabled: Value(user.notificationsEnabled),
              profileVisibleToFamily: Value(user.profileVisibleToFamily),
              cachedAt: DateTime.now(),
            ),
          );
    });
  }

  UserModel _rowToModel(CachedUser row) {
    return UserModel(
      id: row.id,
      phone: row.phone,
      name: row.name,
      address: row.address,
      role: row.role,
      accountStatus: 'ACTIVE',
      languageCode: row.languageCode,
      notificationsEnabled: row.notificationsEnabled,
      profileVisibleToFamily: row.profileVisibleToFamily,
    );
  }
}
