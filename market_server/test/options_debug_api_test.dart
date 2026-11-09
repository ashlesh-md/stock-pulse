import 'dart:convert';
import 'dart:math';

import 'package:market_server/market_server.dart';
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

  Future<(int, Map<String, Object?>)> call(
    String method,
    String path, [
    Object? body,
  ]) async {
    final res = await server.handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {'authorization': 'Bearer $demoToken'},
        body: body is String ? body : (body == null ? null : jsonEncode(body)),
      ),
    );
    return (
      res.statusCode,
      jsonDecode(await res.readAsString()) as Map<String, Object?>,
    );
  }

  String? code(Map<String, Object?> json) =>
      (json['error'] as Map?)?['code'] as String?;

  group('options', () {
    test('expiries list, then the chain for the first expiry', () async {
      final (status, json) = await call(
        'GET',
        '/api/v1/options/NIFTY/expiries',
      );
      expect(status, 200);
      final first = (json['data']! as List).first as Map;
      final (chainStatus, chain) = await call(
        'GET',
        '/api/v1/options/NIFTY/${first['code']}',
      );
      expect(chainStatus, 200);
      expect(chain['data'], isA<Map<String, Object?>>());
    });

    test('an unknown expiry is an error envelope, not a 500', () async {
      final (status, json) = await call(
        'GET',
        '/api/v1/options/NIFTY/1999-01-01',
      );
      expect(status, inInclusiveRange(400, 499));
      expect(code(json), isNotNull);
    });
  });

  group('debug clock', () {
    test('a jump forward moves the market clock', () async {
      final target = server.clock.marketNow().add(const Duration(hours: 1));
      final (status, json) = await call('POST', '/debug/clock', {
        'time': target.toIso8601String(),
      });
      expect(status, 200);
      expect(json, isNotEmpty);
      expect(
        server.clock.marketNow().difference(target).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('a missing or bad time is 400 invalid_time', () async {
      expect(
        code((await call('POST', '/debug/clock', '{x')).$2),
        'invalid_time',
      );
      expect(
        code((await call('POST', '/debug/clock', {'time': 5})).$2),
        'invalid_time',
      );
    });

    test('jumping backwards needs a reset', () async {
      final past = server.clock.marketNow().subtract(const Duration(days: 1));
      final (status, json) = await call('POST', '/debug/clock', {
        'time': past.toIso8601String(),
      });
      expect(status, 409);
      expect(code(json), 'backward_jump_requires_reset');

      final (resetStatus, _) = await call('POST', '/debug/reset', {
        'time': past.toIso8601String(),
      });
      expect(resetStatus, 200);
      expect(
        server.clock.marketNow().difference(past).inSeconds.abs(),
        lessThan(5),
      );
      expect((await call('POST', '/debug/reset')).$1, 200);
    });
  });
}
