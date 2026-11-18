import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/core/network/dio_client.dart';
import 'package:mobile/core/storage/secure_storage_service.dart';

/// Answers by path; records what it was asked.
class _FakeServer implements HttpClientAdapter {
  _FakeServer(this.handle);

  final ResponseBody Function(RequestOptions o) handle;
  final calls = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add('${options.path} ${options.headers['Authorization'] ?? ''}'.trim());
    return handle(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

void main() {
  late SecureStorageService storage;
  late int expired;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    storage = SecureStorageService();
    expired = 0;
  });

  DioClient client(_FakeServer api, _FakeServer auth) {
    final c = DioClient(
      secureStorage: storage,
      onSessionExpired: () async => expired++,
      refreshDio: Dio()..httpClientAdapter = auth,
    );
    c.dio.httpClientAdapter = api;
    return c;
  }

  test('an expired access token is renewed once and the request repeated', () async {
    await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
    final api = _FakeServer((o) => o.headers['Authorization'] == 'Bearer new' ? _json(200, {'ok': true}) : _json(401, {'code': 'UNAUTHORIZED'}));
    final auth = _FakeServer((o) => _json(200, {'tokens': {'accessToken': 'new', 'refreshToken': 'r2'}}));
    final res = await client(api, auth).dio.get<Map<String, dynamic>>('/users/me');

    expect(res.data, {'ok': true});
    expect(api.calls, ['/users/me Bearer old', '/users/me Bearer new']);
    expect(auth.calls.single, startsWith('/auth/refresh'));
    expect(await storage.readAccessToken(), 'new');
    expect(await storage.readRefreshToken(), 'r2', reason: 'rotation: the next refresh token is kept');
    expect(expired, 0);
  });

  test('requests failing together share one refresh', () async {
    await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
    final api = _FakeServer((o) => o.headers['Authorization'] == 'Bearer new' ? _json(200, {}) : _json(401, {}));
    final auth = _FakeServer((o) => _json(200, {'tokens': {'accessToken': 'new', 'refreshToken': 'r2'}}));
    final c = client(api, auth);
    await Future.wait([c.dio.get<dynamic>('/a'), c.dio.get<dynamic>('/b'), c.dio.get<dynamic>('/c')]);
    expect(auth.calls.length, 1);
  });

  test('a refused refresh token signs out (session ended)', () async {
    await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
    final api = _FakeServer((o) => _json(401, {}));
    final auth = _FakeServer((o) => _json(401, {'code': 'SESSION_EXPIRED'}));
    await expectLater(client(api, auth).dio.get<dynamic>('/users/me'), throwsA(isA<DioException>()));
    expect(expired, 1);
    expect(await storage.hasSession(), isFalse);
    expect(await storage.readRefreshToken(), isNull);
  });

  test('offline during the refresh keeps the session (no sign-out)', () async {
    await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
    final api = _FakeServer((o) => _json(401, {}));
    final auth = _FakeServer((o) => throw DioException.connectionError(requestOptions: o, reason: 'offline'));
    await expectLater(client(api, auth).dio.get<dynamic>('/users/me'), throwsA(isA<DioException>()));
    expect(expired, 0);
    expect(await storage.readRefreshToken(), 'r1');
  });

  test('a 401 again after a renewed token does not loop', () async {
    await storage.saveTokens(accessToken: 'old', refreshToken: 'r1');
    final api = _FakeServer((o) => _json(401, {}));
    final auth = _FakeServer((o) => _json(200, {'tokens': {'accessToken': 'new', 'refreshToken': 'r2'}}));
    await expectLater(client(api, auth).dio.get<dynamic>('/users/me'), throwsA(isA<DioException>()));
    expect(api.calls.length, 2);
    expect(auth.calls.length, 1);
    expect(expired, 1);
  });
}
