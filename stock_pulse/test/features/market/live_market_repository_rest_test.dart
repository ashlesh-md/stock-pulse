import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/features/market/data/live_market_repository.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';

import '../../helpers/fake_market_socket.dart';

Map<String, Object?> instrumentJson(
  String id, {
  String kind = 'equity',
  String? underlying,
}) => {
  'id': id,
  'name': id,
  'tickSize': 0.05,
  'lotSize': 1,
  'kind': kind,
  'underlying': ?underlying,
};

void main() {
  late List<http.Request> seen;
  late FakeMarketSocket socket;

  LiveMarketRepository repo(Object? Function(http.Request req) answer) {
    seen = [];
    socket = FakeMarketSocket();
    return LiveMarketRepository(
      ApiClient(
        const AppConfig(host: '127.0.0.1'),
        client: MockClient((req) async {
          seen.add(req);
          final body = answer(req);
          return body is http.Response
              ? body
              : http.Response(jsonEncode(body), 200);
        }),
      ),
      socket,
    );
  }

  final list = {
    'data': [
      instrumentJson('NIFTY', kind: 'index'),
      instrumentJson('TCS'),
      instrumentJson('NIFTY26N1024000CE', kind: 'option', underlying: 'NIFTY'),
    ],
  };

  test('instruments load once, then filter by kind and underlying', () async {
    final r = repo((_) => list);
    final all = await r.getInstruments();
    final options = await r.getInstruments(
      kind: InstrumentKind.option,
      underlying: 'NIFTY',
    );
    expect(all.valueOrNull, hasLength(3));
    expect(options.valueOrNull?.single.id, 'NIFTY26N1024000CE');
    expect(seen, hasLength(1));
    expect(r.instrument('TCS')?.name, 'TCS');
    expect(r.instrument('NOPE'), isNull);
  });

  test('getInstrument finds by id; an unknown id is a 404', () async {
    final r = repo(
      (request) => request.url.path.endsWith('TCS')
          ? instrumentJson('TCS')
          : http.Response('', 404),
    );
    expect((await r.getInstrument('TCS')).valueOrNull?.id, 'TCS');
    final missing = await r.getInstrument('NOPE');
    expect(
      (missing as Failure).error,
      isA<ServerError>().having((e) => e.statusCode, 'status', 404),
    );
  });

  test('a failed instrument load is passed through and not cached', () async {
    var calls = 0;
    final r = repo((_) => ++calls == 1 ? http.Response('', 503) : list);
    expect(await r.getInstrument('TCS'), isA<Failure<Instrument>>());
    expect((await r.getInstruments()).valueOrNull, hasLength(3));
  });

  test(
    'getCandles sends interval, limit and from, and parses candles',
    () async {
      final from = DateTime.utc(2026, 11, 10, 4);
      final r = repo(
        (_) => {
          'data': [
            {'t': 0, 'o': 1, 'h': 2, 'l': 0.5, 'c': 1.5, 'v': 10},
          ],
        },
      );
      final candles = await r.getCandles(
        'TCS',
        CandleInterval.m5,
        from: from,
        limit: 50,
      );
      expect(seen.single.url.path, '/api/v1/instruments/TCS/candles');
      expect(seen.single.url.queryParameters, {
        'interval': '5m',
        'limit': '50',
        'from': '${from.millisecondsSinceEpoch}',
      });
      expect(candles.valueOrNull?.single.close, 1.5);
    },
  );

  test('a sequence gap reloads the watched quotes over REST', () async {
    final r = repo(
      (_) => {
        'data': [
          {'s': 'TCS', 'ltp': 3001, 'ch': 1, 'chp': 0.1, 't': 1},
        ],
      },
    );
    final batches = <List<Object?>>[];
    final sub = r.watchQuotes(['TCS'], FeedMode.quote).listen(batches.add);
    socket.emitResyncNeeded();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(seen.single.url.queryParameters['mode'], 'full');
    expect(batches.single, hasLength(1));
    await sub.cancel();
  });
}
