import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/features/market/data/live_market_repository.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

import '../../../helpers/fake_market_socket.dart';

void main() {
  late FakeMarketSocket socket;
  late LiveMarketRepository repo;
  late List<List<Quote>> batches;
  late StreamSubscription<List<Quote>> sub;

  setUp(() async {
    socket = FakeMarketSocket();
    repo = LiveMarketRepository(
      ApiClient(const AppConfig(host: 'test')),
      socket,
    );
    batches = [];
    sub = repo.watchQuotes(['TCS'], FeedMode.ltp).listen(batches.add);
    socket.emit({
      'type': 'ticks',
      'seq': 1,
      'asOf': 1000,
      'data': [
        {'s': 'TCS', 'ltp': 3000.0, 'ch': 0.0, 'chp': 0.0, 't': 900},
      ],
    });
    await pumpEventQueue();
  });

  tearDown(() async {
    await sub.cancel();
    await repo.dispose();
    await socket.dispose();
  });

  test('a ka frame re-stamps asOf and seq of the quotes it confirms', () async {
    socket.emit({
      'type': 'ka',
      'seq': 2,
      'asOf': 5000,
      'quotes': ['TCS', 'UNKNOWN'],
    });
    await pumpEventQueue();
    final confirmed = batches.last.single;
    expect(
      confirmed.asOf,
      DateTime.fromMillisecondsSinceEpoch(5000, isUtc: true),
    );
    expect(confirmed.seq, 2);
    expect(repo.latest('TCS'), confirmed);
  });

  for (final (name, frame) in [
    (
      'no asOf',
      {
        'type': 'ka',
        'seq': 2,
        'quotes': ['TCS'],
      },
    ),
    (
      'a non-string id',
      {
        'type': 'ka',
        'seq': 2,
        'asOf': 5000,
        'quotes': [7],
      },
    ),
    (
      'a string seq',
      {
        'type': 'ka',
        'seq': 'x',
        'asOf': 5000,
        'quotes': ['TCS'],
      },
    ),
  ]) {
    test('a malformed ka frame ($name) is dropped, not thrown', () async {
      final before = repo.latest('TCS');
      final count = batches.length;
      socket.emit(frame);
      await pumpEventQueue();
      expect(batches.length, count);
      expect(repo.latest('TCS'), before);
    });
  }

  group('instruments', () {
    const tcs = {'id': 'TCS', 'name': 'TCS', 'tickSize': 0.05, 'lotSize': 1};

    LiveMarketRepository withServer(int status, Object body) =>
        LiveMarketRepository(
          ApiClient(
            const AppConfig(host: 'test'),
            client: MockClient(
              (_) async => http.Response(jsonEncode(body), status),
            ),
          ),
          socket,
        );

    test('one instrument is read from the unwrapped server answer', () async {
      final result = await withServer(200, tcs).getInstrument('TCS');
      expect((result as Success<Instrument>).value.symbol, 'TCS');
    });

    test('a loaded list answers later lookups without a request', () async {
      var calls = 0;
      final repo = LiveMarketRepository(
        ApiClient(
          const AppConfig(host: 'test'),
          client: MockClient((_) async {
            calls++;
            return http.Response(
              jsonEncode({
                'data': calls == 1 ? [tcs] : tcs,
              }),
              200,
            );
          }),
        ),
        socket,
      );
      await repo.getInstruments();
      expect(await repo.getInstrument('TCS'), isA<Success<Instrument>>());
      expect(calls, 1);
      final wrapped = await repo.getInstrument('INFY');
      expect((wrapped as Success<Instrument>).value.symbol, 'TCS');
      expect(calls, 2);
    });

    test('the cached list is used when the server is down', () async {
      final repo = withServer(503, {})
        ..seedInstruments([Instrument.fromJson(tcs)]);
      final result = await repo.getInstruments();
      expect((result as Success<List<Instrument>>).value.single.id, 'TCS');
    });
  });
}
