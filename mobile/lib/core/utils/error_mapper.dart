import 'package:dio/dio.dart';

import '../localization/app_strings.dart';

/// The strings error texts use: the app's current language (kept up to date
/// by `stringsProvider`; repositories have no ref). English until then.
AppStrings errorStrings = enStrings;

/// Turns a caught error (almost always a [DioException]) into a short,
/// friendly message in the app's language, safe to show directly. The server
/// sends a machine-readable `code` next to its English `message`; the code
/// decides the text here. Unknown codes and anything unexpected get a generic
/// message (never a stack trace); an unexpected server error shows its
/// support reference ("Ref: 7KQ2-M9").
String friendlyErrorMessage(Object error, [AppStrings? strings]) {
  final s = strings ?? errorStrings;
  if (error is! DioException) return s.errorGeneric;

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return s.errorNetwork;
    default:
      break;
  }

  final data = error.response?.data;
  final body = data is Map ? data : const {};
  final status = error.response?.statusCode ?? 0;
  final code = body['code'] as String? ?? _codeForStatus(status);
  return textForErrorCode(code, s, serverMessage: _message(body['message']), ref: body['ref'] as String?);
}

/// The app's text for a server error code. English keeps the server's own
/// message where it is specific (validation, conflicts); Bengali gets a
/// general sentence there, since server messages are English only.
String textForErrorCode(String? code, AppStrings s, {String? serverMessage, String? ref}) {
  switch (code) {
    case 'PASSWORD_INCORRECT':
      return s.errorPasswordIncorrect;
    case 'INVALID_CREDENTIALS':
      return s.errorInvalidCredentials;
    case 'ACCOUNT_SUSPENDED':
      return s.accountSuspended;
    case 'ACCOUNT_NOT_ACTIVE':
      return s.errorAccountNotActive;
    case 'RESET_CODE_INVALID':
      return s.errorResetCode;
    case 'PHONE_TAKEN':
      return s.errorPhoneTaken;
    case 'NOT_FOUND':
      return s.errorNotFound;
    case 'FORBIDDEN':
      return s.errorForbidden;
    case 'UNAUTHORIZED':
      return s.sessionEnded;
    case 'RATE_LIMITED':
      return s.errorRateLimited;
    case 'PAYLOAD_TOO_LARGE':
      return s.errorPhotoTooLarge;
    case 'MAINTENANCE':
      return s.maintenanceMessage;
    case 'SERVER_ERROR':
      return ref == null ? s.errorGeneric : s.errorServer(ref);
    case 'VALIDATION_FAILED':
    case 'BAD_REQUEST':
    case 'CONFLICT':
      final english = identical(s, enStrings) && serverMessage != null && serverMessage.isNotEmpty;
      return english ? serverMessage : s.errorRequestFailed;
    default:
      return s.errorGeneric;
  }
}

/// For an older server without `code` (and for safety): the status decides.
String? _codeForStatus(int status) {
  if (status >= 500) return status == 503 ? 'MAINTENANCE' : 'SERVER_ERROR';
  return switch (status) {
    400 => 'BAD_REQUEST',
    401 => 'UNAUTHORIZED',
    403 => 'FORBIDDEN',
    404 => 'NOT_FOUND',
    409 => 'CONFLICT',
    413 => 'PAYLOAD_TOO_LARGE',
    429 => 'RATE_LIMITED',
    _ => null,
  };
}

String? _message(Object? message) {
  if (message is String) return message;
  if (message is List && message.isNotEmpty) return message.first.toString();
  return null;
}
