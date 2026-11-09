import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:market_server/market_server.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';

void main() {
  group('universe (FR-3, FR-7)', () {
    test('50 equities + NIFTY, unique ids', () {
      final equities = instruments.where(
        (i) => i.kind == InstrumentKind.equity,
      );
      final indices = instruments.where(
        (i) => i.kind == InstrumentKind.marketIndex,
      );
      expect(equities, hasLength(50));
      expect(indices.map((i) => i.symbol), ['NIFTY']);
      expect(instruments.map((i) => i.symbol).toSet(), hasLength(51));
      // Ids are used in option ids (`-`) and query strings (`&`, `,`).
      for (final i in instruments) {
        expect(i.symbol, matches(RegExp(r'^[A-Z]+$')), reason: i.symbol);
      }
    });

    test(
      'default watchlist is NIFTY, RELIANCE, HDFCBANK and leads the list',
      () {
        expect(defaultWatchlist, ['NIFTY', 'RELIANCE', 'HDFCBANK']);
        expect(instruments.take(3).map((i) => i.symbol), defaultWatchlist);
      },
    );

    test('chain underlyings carry the config strike step', () {
      for (final c in underlyingConfigs.values) {
        final i = instruments.firstWhere((x) => x.symbol == c.symbol);
        expect(i.strikeStep, c.strikeStep, reason: c.symbol);
      }
      expect(underlyingConfigs['NIFTY']!.lotSize, 65);
    });

    test('constituent weights are positive; the index has none', () {
      for (final i in instruments) {
        expect(i.weight > 0, i.kind == InstrumentKind.equity, reason: i.symbol);
      }
    });
  });

  group('metadata (TR-25)', () {
    test('equity band ±20 % of prevClose on the tick grid', () {
      final reliance = instruments.firstWhere((i) => i.symbol == 'RELIANCE');
      expect(reliance.bandFor(100), (low: 80.0, high: 120.0));
      final b = reliance.bandFor(1412.35)!;
      expect(b.low, 1129.9); // 1129.88 rounded up to the tick
      expect(b.high, 1694.8); // 1694.82 rounded down to the tick
    });

    test('index has no band and is not tradable', () {
      final nifty = instruments.first;
      expect(nifty.bandFor(24600), isNull);
      expect(nifty.tradable, isFalse);
      expect(nifty.toJson(prevClose: 24600).containsKey('bandLow'), isFalse);
    });

    test('option band is 0.05 … 3 × prevClose (FR-34)', () {
      const ce = Instrument(
        symbol: 'NIFTY-261117-24500-CE',
        name: 'NIFTY 24500 CE',
        exchange: 'NSE',
        sector: 'Index options',
        basePrice: 100,
        lotSize: 65,
        kind: InstrumentKind.option,
        bandPct: null,
      );
      expect(ce.bandFor(33.37), (low: 0.05, high: 100.1));
    });
  });

  test('NIFTY moves with its constituents while open', () {
    final engine = MarketEngine(
      instruments,
      random: Random(3),
      clock: () => DateTime.utc(2026, 11, 9, 5),
      intradayDays: 1,
      dailyDays: 10,
    );
    final nifty = engine['NIFTY']!;
    final ticks = <Set<String>>[];
    engine.ticks.listen(ticks.add);
    for (var i = 0; i < 20; i++) {
      engine.step();
    }
    expect(ticks.any((t) => t.contains('NIFTY')), isTrue);
    expect(nifty.ltp, closeTo(24600, 24600 * 0.02));
    expect(nifty.volume, 0, reason: 'an index has no volume of its own');
  });

  group('REST /instruments (AC1)', () {
    late MarketServer server;
    late HttpServer http_;
    late Uri base;
    const auth = {'authorization': 'Bearer $demoToken'};

    setUp(() async {
      server = MarketServer(
        engine: MarketEngine(
          instruments,
          random: Random(1),
          intradayDays: 1,
          dailyDays: 10,
        ),
      );
      http_ = await io.serve(server.handler, InternetAddress.loopbackIPv4, 0);
      base = Uri.parse('http://localhost:${http_.port}');
    });

    tearDown(() async {
      await server.close();
      await http_.close(force: true);
    });

    Future<http.Response> get(String path) =>
        http.get(base.resolve(path), headers: auth);

    test('50 equities + NIFTY with kind, lot, tick and band', () async {
      final res = await get('/api/v1/instruments');
      final data = (jsonDecode(res.body) as Map)['data'] as List;
      expect(data, hasLength(51));
      expect([
        for (final j in data.take(3)) (j as Map)['id'],
      ], defaultWatchlist);
      for (final j in data.cast<Map<String, Object?>>()) {
        expect(j['kind'], anyOf('equity', 'index'));
        expect(j['lotSize'], isA<int>());
        expect(j['tickSize'], 0.05);
        if (j['kind'] == 'equity') {
          expect(j['bandLow'], isA<double>(), reason: '${j['id']}');
          expect(j['bandHigh'], greaterThan(j['bandLow']! as double));
        }
      }
      final nifty = data.first as Map;
      expect(nifty['kind'], 'index');
      expect(nifty['strikeStep'], 50);
    });

    test('?kind=index filters; /instruments/{id} and 404', () async {
      final idx =
          (jsonDecode((await get('/api/v1/instruments?kind=index')).body)
                  as Map)['data']
              as List;
      expect(idx.map((j) => (j as Map)['id']), ['NIFTY']);

      final one = await get('/api/v1/instruments/HDFCBANK');
      expect(one.statusCode, 200);
      expect((jsonDecode(one.body) as Map)['strikeStep'], 10);

      final missing = await get('/api/v1/instruments/NOPE');
      expect(missing.statusCode, 404);
      // v1 error shape {"error": {"code", "message"}} is kept.
      expect(
        ((jsonDecode(missing.body) as Map)['error'] as Map)['code'],
        'unknown_symbol',
      );
    });
  });
}
