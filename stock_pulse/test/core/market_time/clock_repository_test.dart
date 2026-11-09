import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/market_time/data/clock_repository.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';

import '../../helpers/fake_market_socket.dart';

ApiClient _api(int status, Object body) => ApiClient(
  const AppConfig(host: 'test'),
  client: MockClient((_) async => http.Response(jsonEncode(body), status)),
);

void main() {
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('without an API the fallback phase is shown at once', () async {
    final first = await ClockRepository().watch().first;
    expect(first, MarketClockState.fallback);
  });

  test('the REST clock is the first phase; a failure falls back', () async {
    final ok = await ClockRepository(
      _api(200, {'phase': 'open', 'nextPhaseAt': 0}),
    ).watch().first;
    expect(ok.phase, MarketPhase.open);
    final failed = await ClockRepository(_api(503, {})).watch().first;
    expect(failed, MarketClockState.fallback);
  });

  test('socket clock and welcome frames win over a late REST answer', () async {
    final rest = Completer<http.Response>();
    final socket = FakeMarketSocket();
    final api = ApiClient(
      const AppConfig(host: 'test'),
      client: MockClient((_) => rest.future),
    );
    final seen = <MarketPhase>[];
    final sub = ClockRepository(
      api,
      socket,
    ).watch().listen((s) => seen.add(s.phase));
    socket
      ..emit({
        'type': 'welcome',
        'clock': {'phase': 'preOpen', 'nextPhaseAt': 0},
      })
      ..emit({'type': 'welcome', 'clock': 'bad'})
      ..emit({'type': 'clock', 'phase': 'nope'})
      ..emit({'type': 'clock', 'phase': 'open', 'nextPhaseAt': 0});
    rest.complete(http.Response(jsonEncode({'phase': 'closed'}), 200));
    await settle();
    await settle();
    expect(seen, [MarketPhase.preOpen, MarketPhase.open]);
    await sub.cancel();
    await socket.dispose();
  });
}
