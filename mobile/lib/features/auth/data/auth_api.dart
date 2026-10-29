import 'package:dio/dio.dart';

import '../../../core/constants/api_endpoints.dart';
import '../domain/auth_tokens.dart';
import '../domain/user_model.dart';

/// Talks to `/auth/*` and `/users/me`. Returns parsed models; throws
/// [DioException] on failure, which callers (repositories) translate into
/// a [Result] / friendly message.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<(UserModel, AuthTokens)> register({
    required String phone,
    required String name,
    required String password,
    String? address,
    String? languagePreference,
    Map<String, dynamic> details = const {},
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: {
        'phone': phone,
        'name': name,
        'password': password,
        if (address != null && address.isNotEmpty) 'address': address,
        if (languagePreference != null)
          'languagePreference': languagePreference,
        // dateOfBirth, genderId, divisionId, districtId, upazilaId (required).
        ...details,
      },
    );
    return _parseAuthResponse(response.data!);
  }

  Future<(UserModel, AuthTokens)> login({
    required String phone,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'phone': phone, 'password': password},
    );
    return _parseAuthResponse(response.data!);
  }

  Future<void> logout() async {
    await _dio.post(ApiEndpoints.logout);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.patch(
      ApiEndpoints.changePassword,
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  /// Public. The server answers the same whether or not the number has an
  /// account, and texts a 6-digit code to the account's phone if it does.
  Future<void> forgotPassword({required String phone}) async {
    await _dio.post(ApiEndpoints.forgotPassword, data: {'phone': phone});
  }

  /// Public. Completes a reset with the SMS code; every earlier session on
  /// every device is signed out by the server.
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    await _dio.post(
      ApiEndpoints.resetPassword,
      data: {'phone': phone, 'code': code, 'newPassword': newPassword},
    );
  }

  /// Permanently deletes the signed-in account (re-authenticated by password).
  Future<void> deleteAccount({required String password}) async {
    await _dio.delete(ApiEndpoints.me, data: {'password': password});
  }

  Future<UserModel> getMe() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.me);
    return UserModel.fromJson(response.data!);
  }

  Future<UserModel> updateMe(Map<String, dynamic> patch) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.me,
      data: patch,
    );
    return UserModel.fromJson(response.data!);
  }

  (UserModel, AuthTokens) _parseAuthResponse(Map<String, dynamic> data) {
    final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    final tokens = AuthTokens.fromJson(data['tokens'] as Map<String, dynamic>);
    return (user, tokens);
  }
}
