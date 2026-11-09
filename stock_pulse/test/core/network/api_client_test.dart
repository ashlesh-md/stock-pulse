import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/core_api.dart';
import 'package:stock_pulse/core/network/domain/endpoint.dart';

void main() {
  late List<http.Request> seen;

  ApiClient clientWith(
    Future<http.Response> Function(http.Request req) handler, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    seen = [];
    return ApiClient(
      const AppConfig(host: '127.0.0.1'),
      timeout: timeout,
      client: MockClient((req) {
        seen.add(req);
        return handler(req);
      }),
    );
  }

  ApiClient client(int status, String body) =>
      clientWith((_) async => http.Response(body, status));

  Matcher failsWith<E extends AppError>() =>
      isA<Failure<Object?>>().having((f) => f.error, 'error', isA<E>());

  test('send adds the auth header exactly once', () async {
    final api = client(200, 'ok');
    final res = await api.send(http.Request('GET', api.uriOf(healthEndpoint)));
    expect(res.statusCode, 200);
    expect(
      seen.single.headers.keys.where((k) => k.toLowerCase() == 'authorization'),
      hasLength(1),
    );
    expect(seen.single.headers['authorization'], startsWith('Bearer '));
  });

  test('a GET endpoint sends its query and decodes the JSON body', () async {
    final api = client(200, '{"data":[1]}');
    final result = await api.call(
      const Endpoint.get('/api/v1/orders', query: {'key': 'k'}),
    );
    expect(seen.single.method, 'GET');
    expect(seen.single.url.path, '/api/v1/orders');
    expect(seen.single.url.queryParameters, {'key': 'k'});
    expect(result.valueOrNull, {
      'data': [1],
    });
  });

  test('a POST endpoint sends JSON and its extra headers', () async {
    final api = client(200, '');
    final result = await api.call(
      const Endpoint.post('/x', body: {'a': 1}, headers: {'x': 'y'}),
    );
    expect(seen.single.method, 'POST');
    expect(seen.single.body, '{"a":1}');
    expect(seen.single.headers['content-type'], startsWith('application/json'));
    expect(seen.single.headers['x'], 'y');
    expect(result, isA<Success<Object?>>().having((s) => s.value, 'v', null));
  });

  test('a POST without body sends no content type', () async {
    final api = client(204, '');
    await api.call(const Endpoint.post('/x'));
    expect(seen.single.headers.containsKey('content-type'), isFalse);
  });

  test('a DELETE endpoint uses the DELETE method', () async {
    final api = client(200, '{}');
    await api.call(const Endpoint.delete('/api/v1/orders/1'));
    expect(seen.single.method, 'DELETE');
    expect(seen.single.url.query, isEmpty);
  });

  test('an error body maps to ServerError with its code', () async {
    final result = await client(
      409,
      '{"error":{"code":"c","message":"m"}}',
    ).call(const Endpoint.post('/debug/clock'));
    expect(
      result,
      isA<Failure<Object?>>().having(
        (f) => f.error,
        'error',
        isA<ServerError>()
            .having((e) => e.statusCode, 'status', 409)
            .having((e) => e.code, 'code', 'c')
            .having((e) => e.message, 'message', 'm'),
      ),
    );
  });

  test('an error without an error body gets an http_<status> code', () async {
    final result = await client(500, '[]').call(const Endpoint.get('/x'));
    expect(
      (result as Failure).error,
      isA<ServerError>().having((e) => e.code, 'code', 'http_500'),
    );
  });

  test('a body that is not JSON is a ParseError', () async {
    expect(
      await client(200, '{nope').call(const Endpoint.get('/x')),
      failsWith<ParseError>(),
    );
  });

  test('no answer within the timeout is a NetworkError', () async {
    final api = clientWith(
      (_) => Completer<http.Response>().future,
      timeout: const Duration(milliseconds: 10),
    );
    expect(await api.call(const Endpoint.get('/x')), failsWith<NetworkError>());
  });

  test('a client exception is a NetworkError', () async {
    final api = clientWith((_) => throw http.ClientException('refused'));
    expect(await api.call(const Endpoint.get('/x')), failsWith<NetworkError>());
  });

  test('a socket reset while reading is a NetworkError', () async {
    final api = clientWith((_) => throw const SocketException('reset'));
    expect(await api.call(const Endpoint.get('/x')), failsWith<NetworkError>());
  });

  group('getHealth', () {
    test('200 is healthy, anything else is a ServerError', () async {
      expect(await client(200, 'ok').getHealth(), isA<Success<void>>());
      expect(
        await client(503, '').getHealth(),
        isA<Failure<void>>().having(
          (f) => f.error,
          'error',
          isA<ServerError>().having((e) => e.code, 'code', 'http_503'),
        ),
      );
    });

    test('a slow server is a NetworkError', () async {
      final api = clientWith((_) => Completer<http.Response>().future);
      final result = await api.getHealth(
        timeout: const Duration(milliseconds: 10),
      );
      expect(
        result,
        isA<Failure<void>>().having((f) => f.error, 'e', isA<NetworkError>()),
      );
    });

    test('an unreachable server is a NetworkError', () async {
      final api = clientWith((_) => throw const SocketException('down'));
      expect(
        await api.getHealth(),
        isA<Failure<void>>().having((f) => f.error, 'e', isA<NetworkError>()),
      );
    });
  });
}
