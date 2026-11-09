import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';

void main() {
  const open = MarketClockState(
    phase: MarketPhase.open,
    marketOffsetMs: 1000,
    mode: 'demo',
    tradingDay: '2026-11-10',
  );

  test('parses nextPhaseAt from epoch ms or ISO text', () {
    final fromMs = MarketClockState.fromJson({
      'phase': 'open',
      'nextPhaseAt': 0,
    });
    final fromIso = MarketClockState.fromJson({
      'phase': 'closed',
      'nextPhaseAt': '1970-01-01T00:00:00.000Z',
      'overridden': true,
    });
    expect(fromMs.nextPhaseAt, DateTime.utc(1970));
    expect(fromIso.nextPhaseAt, DateTime.utc(1970));
    expect(fromIso.overridden, isTrue);
    expect(fromMs.mode, 'real');
  });

  test('equal by value; copyWith changes one field', () {
    final closed = open.copyWith(phase: MarketPhase.closed);
    expect(closed.phase, MarketPhase.closed);
    expect(closed.marketOffsetMs, 1000);
    expect(closed, isNot(open));
    expect(open.copyWith(), open);
    expect(open.copyWith().hashCode, open.hashCode);
  });

  test('market time is server time plus the offset', () {
    expect(
      open.marketNow(DateTime.utc(2026)),
      DateTime.utc(2026, 1, 1, 0, 0, 1),
    );
  });

  test('a fake clock moves only when told', () {
    final clock = FakeClock(DateTime.utc(2026))
      ..advance(const Duration(seconds: 2));
    expect(clock.now(), DateTime.utc(2026, 1, 1, 0, 0, 2));
    clock.set(DateTime.utc(2027));
    expect(clock.now(), DateTime.utc(2027));
    expect(const SystemClock().now().isUtc, isFalse);
  });

  test(
    'marketClockProvider reports the fallback clock when GET /clock fails',
    () async {
      final api = ApiClient(
        const AppConfig(host: 'localhost'),
        client: MockClient((_) async => http.Response('', 503)),
      );
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(marketClockProvider, (_, _) {});
      await pumpEventQueue();
      expect(sub.read().value, MarketClockState.fallback);
    },
  );

  test('freshnessTickProvider ticks server time every 250 ms', () async {
    final clock = _SteppingClock();
    final container = ProviderContainer(
      overrides: [clockProvider.overrideWithValue(clock)],
    );
    addTearDown(container.dispose);
    final ticks = <DateTime>[];
    container.listen(
      freshnessTickProvider,
      (_, next) => ticks.add(next.requireValue),
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(ticks, hasLength(greaterThanOrEqualTo(2)));
    expect(ticks.first, DateTime.utc(2026, 1, 1, 0, 0, 1));
  });
}

/// One second later on every read.
class _SteppingClock implements Clock {
  var _seconds = 0;

  @override
  DateTime now() => DateTime.utc(2026, 1, 1, 0, 0, ++_seconds);
}
