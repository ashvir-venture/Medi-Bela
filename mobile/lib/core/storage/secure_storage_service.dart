import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_config.dart';

/// The ONLY place the JWT access token is read or written.
///
/// Backed by Keychain (iOS) / Keystore-encrypted prefs (Android). Tokens
/// must never end up in the Drift database — Drift is a plain SQLite file
/// on disk with no encryption, which is fine for cached medical-looking
/// display data but not for credentials.
class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  final FlutterSecureStorage _storage;

  Future<void> saveTokens({required String accessToken}) =>
      _storage.write(key: SecureStorageKeys.accessToken, value: accessToken);

  Future<String?> readAccessToken() =>
      _storage.read(key: SecureStorageKeys.accessToken);

  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: SecureStorageKeys.accessToken),
      // Leftover from builds that used a refresh token.
      _storage.delete(key: SecureStorageKeys.legacyRefreshToken),
    ]);
  }

  Future<String?> readRegisteredPushToken() =>
      _storage.read(key: SecureStorageKeys.registeredPushToken);

  Future<void> saveRegisteredPushToken(String token) =>
      _storage.write(key: SecureStorageKeys.registeredPushToken, value: token);

  Future<void> clearRegisteredPushToken() =>
      _storage.delete(key: SecureStorageKeys.registeredPushToken);

  Future<bool> hasSession() async {
    final token = await readAccessToken();
    return token != null && token.isNotEmpty;
  }
}
