import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/domain/endpoint.dart';

void main() {
  const endpoint = Endpoint.get('/probe');
  test('F3 F5 transient GET failures retry once after one second', () async {
    for (final timeout in [false, true]) {
      var calls = 0;
      final waits = <Duration>[];
      final api = ApiClient(
        const AppConfig(host: '127.0.0.1'),
        client: MockClient((request) async {
          calls++;
          if (timeout) throw TimeoutException('late response');
          return http.Response(
            '{"error":{"code":"busy","message":"busy"}}',
            503,
          );
        }),
        wait: (delay) async => waits.add(delay),
      );
      addTearDown(api.close);
      final result = await api.call(endpoint);
      expect(result, isA<Failure<Object?>>());
      expect(calls, 2);
      expect(waits, [const Duration(seconds: 1)]);
    }
  });
  test(
    'F4 rejected reads preserve the server reason without a retry loop',
    () async {
      for (final status in [400, 401, 404, 409, 422]) {
        var calls = 0;
        final api = ApiClient(
          const AppConfig(host: '127.0.0.1'),
          client: MockClient((request) async {
            calls++;
            return http.Response(
              '{"error":{"code":"reason","message":"private"}}',
              status,
            );
          }),
          wait: (_) async => fail('unexpected retry'),
        );
        addTearDown(api.close);
        final result = await api.call(endpoint) as Failure<Object?>;
        expect((result.error as ServerError).code, 'reason');
        expect(calls, 1);
      }
    },
  );
  test(
    'F4 429 honors seconds and HTTP dates, falling back to two seconds',
    () async {
      for (final header in <String?>[
        null,
        '3',
        'Mon, 01 Jan 2001 00:00:00 GMT',
        'invalid',
        'Mon, 01 Xxx 2001 00:00:00 GMT',
        'Mon, 01 Jan 2400 00:00:00 GMT',
      ]) {
        var calls = 0;
        final waits = <Duration>[];
        final api = ApiClient(
          const AppConfig(host: '127.0.0.1'),
          client: MockClient((request) async {
            calls++;
            return calls == 1
                ? http.Response(
                    '{"error":{"code":"rate_limited"}}',
                    429,
                    headers: {'Retry-After': ?header},
                  )
                : http.Response('{}', 200);
          }),
          wait: (delay) async => waits.add(delay),
        );
        addTearDown(api.close);
        expect(await api.call(endpoint), isA<Success<Object?>>());
        expect(calls, 2);
        if (header == '3') {
          expect(waits.single, const Duration(seconds: 3));
        } else if (header?.contains('2001') == true &&
            !header!.contains('Xxx')) {
          expect(waits.single, Duration.zero);
        } else if (header?.contains('2400') == true) {
          expect(waits.single, greaterThan(const Duration(days: 1)));
        } else {
          expect(waits.single, const Duration(seconds: 2));
        }
      }
    },
  );
  test('F3 order POSTs do not gain an extra retry layer', () async {
    var calls = 0;
    final api = ApiClient(
      const AppConfig(host: '127.0.0.1'),
      client: MockClient((request) async {
        calls++;
        expect(request.body, '{"clientKey":"same"}');
        return http.Response('{"error":{"code":"busy"}}', 503);
      }),
      wait: (_) async => fail('order retries belong to its submit flow'),
    );
    addTearDown(api.close);
    expect(
      await api.call(
        const Endpoint.post('/orders', body: {'clientKey': 'same'}),
      ),
      isA<Failure<Object?>>(),
    );
    expect(calls, 1);
  });
}
