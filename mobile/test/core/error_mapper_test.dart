import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/localization/app_strings.dart';
import 'package:mobile/core/utils/error_mapper.dart';

DioException _server(int status, Map<String, dynamic> body) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: body),
  );
}

void main() {
  test('codes map to the app language, English and Bengali', () {
    final wrong = _server(403, {'code': 'PASSWORD_INCORRECT', 'message': 'Password is incorrect'});
    expect(friendlyErrorMessage(wrong, enStrings), enStrings.errorPasswordIncorrect);
    expect(friendlyErrorMessage(wrong, bnStrings), bnStrings.errorPasswordIncorrect);

    final banned = _server(403, {'code': 'ACCOUNT_SUSPENDED', 'message': 'This account is under suspension.'});
    expect(friendlyErrorMessage(banned, bnStrings), bnStrings.accountSuspended);

    expect(friendlyErrorMessage(_server(429, {'code': 'RATE_LIMITED'}), bnStrings), bnStrings.errorRateLimited);
    expect(friendlyErrorMessage(_server(503, {'code': 'MAINTENANCE'}), enStrings), enStrings.maintenanceMessage);
    expect(friendlyErrorMessage(_server(401, {'code': 'UNAUTHORIZED'}), enStrings), enStrings.sessionEnded);
  });

  test('unexpected server error shows the support ref', () {
    final e = _server(500, {'code': 'SERVER_ERROR', 'ref': '7KQ2-M9', 'message': 'Internal server error'});
    expect(friendlyErrorMessage(e, enStrings), 'Something went wrong. Ref: 7KQ2-M9');
    expect(friendlyErrorMessage(e, bnStrings), contains('7KQ2-M9'));
  });

  test('specific English server messages stay in English; Bengali gets a general sentence', () {
    final e = _server(409, {'code': 'CONFLICT', 'message': 'This person is already a family member'});
    expect(friendlyErrorMessage(e, enStrings), 'This person is already a family member');
    expect(friendlyErrorMessage(e, bnStrings), bnStrings.errorRequestFailed);
  });

  test('unknown codes and odd errors fall back to the generic message', () {
    expect(friendlyErrorMessage(_server(418, {'code': 'TEAPOT'}), bnStrings), bnStrings.errorGeneric);
    expect(friendlyErrorMessage(StateError('boom'), enStrings), enStrings.errorGeneric);
  });

  test('no answer from the server: the connection message', () {
    final e = DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);
    expect(friendlyErrorMessage(e, bnStrings), bnStrings.errorNetwork);
  });

  test('only MAINTENANCE (or a 503 without a code) is maintenance; an AI outage is a message', () {
    expect(isMaintenanceResponse(_server(503, {'code': 'MAINTENANCE'}).response), isTrue);
    expect(isMaintenanceResponse(_server(503, {}).response), isTrue);
    expect(isMaintenanceResponse(_server(503, {'code': 'AI_UNAVAILABLE'}).response), isFalse);
    expect(isMaintenanceResponse(_server(503, {'code': 'SERVICE_UNAVAILABLE'}).response), isFalse);
    expect(isMaintenanceResponse(_server(500, {'code': 'SERVER_ERROR'}).response), isFalse);

    final ai = _server(503, {'code': 'AI_UNAVAILABLE', 'message': 'The assistant is currently unavailable'});
    expect(friendlyErrorMessage(ai, enStrings), enStrings.errorAiUnavailable);
    expect(friendlyErrorMessage(ai, bnStrings), bnStrings.errorAiUnavailable);
  });

  test('an older server without code: the status decides', () {
    expect(friendlyErrorMessage(_server(404, {'message': 'Not found'}), enStrings), enStrings.errorNotFound);
    expect(friendlyErrorMessage(_server(502, {}), enStrings), enStrings.errorGeneric);
  });
}
