/// Central place for values that will change between environments.
///
/// [apiBaseUrl] points at the Phase 1 NestJS backend, which serves under
/// the `/api` prefix (see backend `main.ts`: `app.setGlobalPrefix`).
///
/// For local development:
/// - Android emulator: `http://10.0.2.2:3001/api`
/// - iOS simulator / desktop: `http://localhost:3001/api`
/// - Physical device: `http://<your-machine-lan-ip>:3001/api`
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3001/api',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// How often the sync engine retries the outbox when the app is in the
  /// foreground and online (in addition to connectivity-change triggers).
  static const Duration syncPollInterval = Duration(seconds: 30);

  static const int maxOutboxRetries = 5;
}

/// Keys used in `flutter_secure_storage`. Tokens NEVER go into Drift/SQLite.
class SecureStorageKeys {
  SecureStorageKeys._();

  static const String accessToken = 'auth_access_token';
  static const String legacyRefreshToken = 'auth_refresh_token'; // no longer used; only deleted
  // Last FCM token successfully registered with the backend. Secure storage
  // (not prefs/Drift): a push token is a delivery credential for this device.
  static const String registeredPushToken = 'push_registered_token';
}

/// Keys used for small non-sensitive local preferences (SharedPreferences).
class PrefsKeys {
  PrefsKeys._();

  static const String languageCode = 'pref_language_code';
}
