import 'package:dio/dio.dart';

import '../constants/api_endpoints.dart';
import '../constants/app_config.dart';
import '../storage/secure_storage_service.dart';
import '../utils/error_mapper.dart';

/// Builds the single shared [Dio] instance used by every `*Api` class.
///
/// - attaches `Authorization: Bearer <access token>` to every request
/// - Round 18: the access token lasts 15 minutes. A 401 on a non-auth route
///   renews it once with the refresh token (POST /auth/refresh, one refresh
///   at a time) and repeats the request. Only when the server refuses the
///   refresh token itself (401) is the session cleared and
///   [onSessionExpired] called, so the UI drops back to the login screen.
///
/// Offline / timeout / 5xx errors are NOT 401s, so being offline never logs
/// the user out (a refresh that can't reach the server keeps the session).
class DioClient {
  DioClient({
    required SecureStorageService secureStorage,
    required Future<void> Function() onSessionExpired,
    void Function()? onMaintenance,
    Dio? refreshDio,
  })  : _secureStorage = secureStorage,
        _onSessionExpired = onSessionExpired,
        _onMaintenance = onMaintenance {
    final options = BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      contentType: 'application/json',
    );
    _dio = Dio(options);
    // No interceptors: a refresh must never trigger another refresh.
    _refreshDio = refreshDio ?? Dio(options);

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
          final path = error.requestOptions.path;
          final isAuthRoute = path == ApiEndpoints.login || path == ApiEndpoints.register || path == ApiEndpoints.logout;

          if (isUnauthorized && !isAuthRoute) {
            final alreadyRetried = error.requestOptions.extra[_retriedKey] == true;
            final outcome = alreadyRetried ? _RefreshOutcome.refused : await _refreshOnce();
            if (outcome == _RefreshOutcome.renewed) {
              try {
                final retry = error.requestOptions..extra[_retriedKey] = true;
                retry.headers['Authorization'] = 'Bearer ${await _secureStorage.readAccessToken()}';
                return handler.resolve(await _dio.fetch<dynamic>(retry));
              } on DioException catch (e) {
                return handler.next(e);
              }
            }
            if (outcome == _RefreshOutcome.refused) {
              await _secureStorage.clearTokens();
              await _onSessionExpired();
            }
          }
          // MAINTENANCE_MODE on the server: every route but /health is 503 MAINTENANCE.
          if (isMaintenanceResponse(error.response)) _onMaintenance?.call();
          handler.next(error);
        },
      ),
    );
  }

  static const _retriedKey = 'mb_retried_after_refresh';

  late final Dio _dio;
  late final Dio _refreshDio;
  final SecureStorageService _secureStorage;
  final Future<void> Function() _onSessionExpired;
  final void Function()? _onMaintenance;
  Future<_RefreshOutcome>? _refreshing;

  Dio get dio => _dio;

  /// Requests that hit 401 together share one refresh.
  Future<_RefreshOutcome> _refreshOnce() {
    return _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  }

  Future<_RefreshOutcome> _refresh() async {
    final refreshToken = await _secureStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return _RefreshOutcome.refused;
    try {
      final res = await _refreshDio.post<Map<String, dynamic>>(ApiEndpoints.refresh, data: {'refreshToken': refreshToken});
      final tokens = res.data?['tokens'] as Map<String, dynamic>?;
      final access = tokens?['accessToken'] as String?;
      if (access == null) return _RefreshOutcome.refused;
      await _secureStorage.saveTokens(accessToken: access, refreshToken: tokens?['refreshToken'] as String?);
      return _RefreshOutcome.renewed;
    } on DioException catch (e) {
      // Refused (expired, revoked, reused, account paused): sign in again.
      // Anything else (offline, timeout, 5xx): keep the session for later.
      final status = e.response?.statusCode;
      return status == 401 || status == 403 ? _RefreshOutcome.refused : _RefreshOutcome.unreachable;
    }
  }
}

enum _RefreshOutcome { renewed, refused, unreachable }
