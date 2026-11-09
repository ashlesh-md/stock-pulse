import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/http_debug_client.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';

void main() {
  late List<http.Request> seen;

  HttpDebugClient debugClient(int status, Object? body) {
    seen = [];
    return HttpDebugClient(
      ApiClient(
        const AppConfig(host: '127.0.0.1'),
        client: MockClient((req) async {
          seen.add(req);
          return http.Response(body == null ? '' : jsonEncode(body), status);
        }),
      ),
    );
  }

  const clockJson = {
    'phase': 'preOpen',
    'marketOffsetMs': 5,
    'mode': 'demo',
    'tradingDay': '2026-11-10',
  };

  test('setClock posts the UTC time and parses the clock in data', () async {
    final client = debugClient(200, {'data': clockJson});
    final result = await client.setClock(DateTime.utc(2026, 11, 10, 3));
    expect(seen.single.url.path, '/debug/clock');
    expect(jsonDecode(seen.single.body), {'time': '2026-11-10T03:00:00.000Z'});
    expect(result.valueOrNull?.phase, MarketPhase.preOpen);
  });

  test('setClock also reads a bare clock body', () async {
    final result = await debugClient(
      200,
      clockJson,
    ).setClock(DateTime.utc(2026));
    expect(result.valueOrNull?.marketOffsetMs, 5);
  });

  test('a backward jump keeps the server code', () async {
    final result = await debugClient(409, {
      'error': {'code': 'backward_jump_requires_reset', 'message': 'm'},
    }).setClock(DateTime.utc(2026));
    expect(
      (result as Failure).error,
      isA<ServerError>().having(
        (e) => e.code,
        'code',
        'backward_jump_requires_reset',
      ),
    );
  });

  test('a clock body of the wrong shape is a ParseError', () async {
    final result = await debugClient(200, {'data': 1}).setClock(DateTime(2026));
    expect((result as Failure).error, isA<ParseError>());
  });

  test('reset posts to /debug/reset and succeeds with no value', () async {
    final result = await debugClient(200, {'ok': true}).reset();
    expect(seen.single.url.path, '/debug/reset');
    expect(result, isA<Success<void>>());
  });

  test('debugClientProvider builds the REST debug client', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(host: 'h')),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(debugClientProvider), isA<HttpDebugClient>());
  });
}
