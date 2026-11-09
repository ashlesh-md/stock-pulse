import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:market_server/src/fault_injector.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

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
      debug: true,
    );
  });

  tearDown(() => server.close());

  Future<Response> send(
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
  }) async => server.handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: {'authorization': 'Bearer $demoToken', ...headers},
      body: body == null ? null : jsonEncode(body),
    ),
  );

  Future<Map<String, Object?>> json(Response res) async =>
      jsonDecode(await res.readAsString()) as Map<String, Object?>;

  String? code(Map<String, Object?> body) =>
      (body['error'] as Map?)?['code'] as String?;

  test(
    'FR-122 S-8 AC3 a status fault applies once, then the route works',
    () async {
      final queued = await send(
        'POST',
        '/debug/faults',
        body: {'path': '/api/v1/clock', 'method': 'GET', 'status': 503},
      );
      expect(queued.statusCode, 200);
      final faulted = await send('GET', '/api/v1/clock');
      expect(faulted.statusCode, 503);
      expect(code(await json(faulted)), 'fault_injected');
      expect((await send('GET', '/api/v1/clock')).statusCode, 200);
    },
  );

  test('FR-122 a delay fault holds the reply for its delay', () async {
    await send(
      'POST',
      '/debug/faults',
      body: {'path': '/api/v1/clock', 'method': 'GET', 'delayMs': 150},
    );
    final watch = Stopwatch()..start();
    final res = await send('GET', '/api/v1/clock');
    expect(res.statusCode, 200);
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(140));
  });

  test(
    'a fault with count 2 hits two requests; DELETE clears the queue',
    () async {
      await send(
        'POST',
        '/debug/faults',
        body: {'path': '/api/v1/', 'method': 'get', 'status': 500, 'count': 2},
      );
      expect((await send('GET', '/api/v1/clock')).statusCode, 500);
      expect((await send('GET', '/api/v1/instruments')).statusCode, 500);
      expect((await send('GET', '/api/v1/clock')).statusCode, 200);

      await send(
        'POST',
        '/debug/faults',
        body: {'path': '/api/v1/clock', 'method': 'GET', 'status': 500},
      );
      final cleared = await send('DELETE', '/debug/faults');
      expect((await json(cleared))['pending'], 0);
      expect((await send('GET', '/api/v1/clock')).statusCode, 200);
    },
  );

  test('a fault without a path is 400 invalid_fault', () async {
    final res = await send('POST', '/debug/faults', body: {'status': 500});
    expect(res.statusCode, 400);
    expect(code(await json(res)), 'invalid_fault');
    final notJson = await server.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/debug/faults'),
        headers: {'authorization': 'Bearer $demoToken'},
        body: 'nope',
      ),
    );
    expect(notJson.statusCode, 400);
  });

  test('FR-122 dropAckAfterStore on POST /orders stores once and drops the '
      'ack', () async {
    await send(
      'POST',
      '/debug/faults',
      body: {
        'path': '/api/v1/orders',
        'method': 'POST',
        'dropAckAfterStore': true,
        'delayMs': 10,
      },
    );
    final res = await send(
      'POST',
      '/api/v1/orders',
      headers: {'idempotency-key': 'k-1'},
      body: {
        'symbol': 'TCS',
        'side': 'buy',
        'type': 'market',
        'product': 'cnc',
        'quantity': 1,
      },
    );
    expect(res.statusCode, 504);
    expect(code(await json(res)), 'ack_dropped');
    expect(server.broker.orders, hasLength(1));

    final lookup = await send('GET', '/api/v1/orders?key=k-1');
    expect(lookup.statusCode, 200);
    final stored = await json(lookup);
    expect(stored['data'], isA<Map<String, Object?>>());

    final retry = await send(
      'POST',
      '/api/v1/orders',
      headers: {'idempotency-key': 'k-1'},
      body: {
        'symbol': 'TCS',
        'side': 'buy',
        'type': 'market',
        'product': 'cnc',
        'quantity': 1,
      },
    );
    expect(retry.statusCode, 201);
    expect((await json(retry))['data'], stored['data']);
    expect(server.broker.orders, hasLength(1));
  });

  test(
    'a dropped ack with no delay waits longer than the app timeout',
    () async {
      final clock = FakeMarketClock(
        wallStart: DateTime.utc(2026, 11, 1, 6),
        marketStart: DateTime.utc(2026, 11, 10, 4, 30),
      );
      final faults = FaultInjector()
        ..add(FaultPlan(path: '/x', method: 'GET', dropAckAfterStore: true))
        ..add(FaultPlan(path: '/x', method: 'GET', count: 0));
      expect(faults.pending, 1);
      var handled = 0;
      Response? reply;
      final handler = faultInjection(faults, clock)((_) {
        handled++;
        return Response.ok('stored');
      });
      unawaited(
        Future.value(
          handler(Request('GET', Uri.parse('http://localhost/x'))),
        ).then((r) => reply = r),
      );
      await Future<void>.delayed(Duration.zero);
      expect(handled, 1);
      clock.advance(const Duration(seconds: 19));
      await Future<void>.delayed(Duration.zero);
      expect(reply, isNull);
      clock.advance(const Duration(seconds: 1));
      await Future<void>.delayed(Duration.zero);
      expect(reply?.statusCode, 504);
    },
  );

  test('FR-124 GET /debug/subscriptions sums every session', () async {
    final res = await send('GET', '/debug/subscriptions');
    final body = await json(res);
    expect(body['data'] ?? body, {
      'sessions': <Object?>[],
      'totals': {'sessions': 0, 'quotes': 0, 'chains': 0},
      'activeAiAnswers': 0,
    });
  });

  test('FR-121 /debug/freeze?symbol freezes one id; unknown is 404', () async {
    final ok = await send('POST', '/debug/freeze?symbol=RELIANCE&seconds=6');
    expect(ok.statusCode, 200);
    expect(server.gateway.isIdFrozen('RELIANCE'), isTrue);
    expect(server.gateway.isIdFrozen('TCS'), isFalse);
    final bad = await send('POST', '/debug/freeze?symbol=NOPE');
    expect(bad.statusCode, 404);
  });
}
