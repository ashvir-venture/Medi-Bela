import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../constants/app_config.dart';
import '../storage/secure_storage_service.dart';

/// Builds the single shared [Dio] instance used by every `*Api` class.
///
/// - attaches `Authorization: Bearer <jwt>` to every request
/// - if the server answers 401 (token expired / account disabled) on a
///   non-auth route, clears the stored session and notifies
///   [onSessionExpired] so the UI drops back to the login screen.
///
/// MVP: there is a single JWT and no refresh flow. Offline / timeout / 5xx
/// errors are NOT 401s, so being offline never logs the user out.
class DioClient {
  DioClient({
    required SecureStorageService secureStorage,
    required Future<void> Function() onSessionExpired,
  })  : _secureStorage = secureStorage,
        _onSessionExpired = onSessionExpired {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: 'application/json',
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isUnauthorized = error.response?.statusCode == 401;
          final isAuthRoute = error.requestOptions.path == ApiEndpoints.login ||
              error.requestOptions.path == ApiEndpoints.register;

          if (isUnauthorized && !isAuthRoute) {
            await _secureStorage.clearTokens();
            await _onSessionExpired();
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final SecureStorageService _secureStorage;
  final Future<void> Function() _onSessionExpired;

  Dio get dio => _dio;
}
