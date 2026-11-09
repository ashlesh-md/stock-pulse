import 'dart:convert';
import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:market_server/src/rest_api.dart' show latency;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// REST routes called in process through [MarketServer.handler].
void main() {
  late MarketServer server;

  setUp(() {
    server = MarketServer(
      engine: MarketEngine(
        instruments,
        random: Random(3),
        intradayDays: 1,
        dailyDays: 5,
      ),
    );
  });

  tearDown(() => server.close());

  Future<(int, Object?)> call(
    String method,
    String path, {
    Object? body,
  }) async {
    final res = await server.handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {'authorization': 'Bearer $demoToken'},
        body: body is String ? body : (body == null ? null : jsonEncode(body)),
      ),
    );
    final text = await res.readAsString();
    return (res.statusCode, text.startsWith('{') ? jsonDecode(text) : text);
  }

  String? errorCode(Object? json) =>
      ((json! as Map)['error'] as Map?)?['code'] as String?;

  test('quotes without symbols returns every instrument', () async {
    final (status, json) = await call('GET', '/api/v1/quotes');
    expect(status, 200);
    expect(((json! as Map)['data'] as List), hasLength(instruments.length));
  });

  test('candles of an unknown symbol is 404 unknown_symbol', () async {
    final (status, json) = await call(
      'GET',
      '/api/v1/instruments/NOPE/candles',
    );
    expect(status, 404);
    expect(errorCode(json), 'unknown_symbol');
  });

  group('POST /orders', () {
    test('a body that is not JSON is 400 invalid_json', () async {
      final (status, json) = await call('POST', '/api/v1/orders', body: '{x');
      expect(status, 400);
      expect(errorCode(json), 'invalid_json');
    });

    test('a JSON body that is not an object is 400 invalid_json', () async {
      final (status, json) = await call('POST', '/api/v1/orders', body: '[1]');
      expect(status, 400);
      expect(errorCode(json), 'invalid_json');
    });

    test('a missing side is 400 invalid_order', () async {
      final (status, json) = await call(
        'POST',
        '/api/v1/orders',
        body: {'symbol': 'TCS', 'type': 'market', 'quantity': 1},
      );
      expect(status, 400);
      expect(errorCode(json), 'invalid_order');
    });

    for (final (field, bad) in [
      ('quantity', '5'),
      ('lots', 1.5),
      ('triggerPrice', 'high'),
      ('limitPrice', true),
    ]) {
      test('a wrong-typed $field is 400 invalid_order, not a 500', () async {
        final (status, json) = await call(
          'POST',
          '/api/v1/orders',
          body: {
            'symbol': 'TCS',
            'side': 'buy',
            'type': 'limit',
            'quantity': 1,
            field: bad,
          },
        );
        expect(status, 400);
        expect(errorCode(json), 'invalid_order');
      });
    }

    test('a broker rejection keeps its status and code', () async {
      final (status, json) = await call(
        'POST',
        '/api/v1/orders',
        body: {
          'symbol': 'NOPE',
          'side': 'buy',
          'type': 'market',
          'quantity': 1,
        },
      );
      expect(status, 404);
      expect(errorCode(json), 'unknown_symbol');
    });
  });

  group('DELETE /orders/<id>', () {
    test('cancels an open limit order', () async {
      final ltp = server.engine['TCS']!.ltp;
      final (_, placed) = await call(
        'POST',
        '/api/v1/orders',
        body: {
          'symbol': 'TCS',
          'side': 'buy',
          'type': 'limit',
          'quantity': 1,
          'limitPrice': (ltp * 0.85).roundToDouble(),
        },
      );
      final id = ((placed! as Map)['data'] as Map)['id'];
      final (status, json) = await call('DELETE', '/api/v1/orders/$id');
      expect(status, 200);
      expect(((json! as Map)['data'] as Map)['status'], 'cancelled');
    });

    test('an unknown order is 404 not_found', () async {
      final (status, json) = await call('DELETE', '/api/v1/orders/ORD9');
      expect(status, 404);
      expect(errorCode(json), 'not_found');
    });
  });

  group('debug routes', () {
    test('drop-connections reports how many sockets it closed', () async {
      final (status, text) = await call('POST', '/debug/drop-connections');
      expect(status, 200);
      expect(text, 'dropped 0 connection(s)\n');
    });

    test('freeze takes seconds from the query, 15 by default', () async {
      expect(
        (await call('POST', '/debug/freeze?seconds=2')).$2,
        'frozen for 2s\n',
      );
      expect((await call('POST', '/debug/freeze')).$2, 'frozen for 15s\n');
    });

    test('skip-seq answers once it has skipped', () async {
      expect(
        (await call('POST', '/debug/skip-seq')).$2,
        'skipped one sequence number\n',
      );
    });
  });

  test('latency delays only api routes', () async {
    final handler = latency(const Duration(milliseconds: 30))(
      (_) => Response.ok('ok'),
    );
    final watch = Stopwatch()..start();
    await handler(Request('GET', Uri.parse('http://localhost/health')));
    final health = watch.elapsedMilliseconds;
    await handler(Request('GET', Uri.parse('http://localhost/api/v1/x')));
    expect(health, lessThan(30));
    expect(watch.elapsedMilliseconds - health, greaterThanOrEqualTo(30));
  });
}
