import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/market_time/domain/server_clock.dart';

void main() {
  final server = DateTime.utc(2026, 11, 10, 5);

  test('welcome sets the offset; device +30 s still reads server time', () {
    final device = FakeClock(server.add(const Duration(seconds: 30)));
    final clock = ServerClock(device);
    expect(clock.synced, isFalse);

    clock.onWelcome(server.millisecondsSinceEpoch, device.now());

    expect(clock.synced, isTrue);
    expect(clock.now(), server);
    device.advance(const Duration(seconds: 2));
    expect(clock.now(), server.add(const Duration(seconds: 2)));
  });

  test(
    'pong: the lowest-RTT sample of the last 5 wins; negative RTT ignored',
    () {
      final device = FakeClock(server);
      final clock = ServerClock(device);
      final t0 = server.millisecondsSinceEpoch;

      // rtt 100 → offset = (t0 + 1000) + 50 − (t0 + 100) = 950
      clock.onPong(
        t0,
        t0 + 1000,
        server.add(const Duration(milliseconds: 100)),
      );
      // rtt 20 → offset = (t0 + 1000) + 10 − (t0 + 20) = 990
      clock.onPong(t0, t0 + 1000, server.add(const Duration(milliseconds: 20)));
      // rtt 60
      clock.onPong(t0, t0 + 500, server.add(const Duration(milliseconds: 60)));
      // RTTs 80 and 50 bring the first rolling window to five samples.
      clock.onPong(t0, t0 + 970, server.add(const Duration(milliseconds: 80)));
      clock.onPong(t0, t0 + 985, server.add(const Duration(milliseconds: 50)));
      expect(clock.offset, const Duration(milliseconds: 990));

      // The best sample in the previous window ages out; RTT 10 now wins.
      clock.onPong(t0, t0 + 880, server.add(const Duration(milliseconds: 10)));
      expect(clock.offset, const Duration(milliseconds: 875));

      clock.onPong(t0 + 10000, t0, server); // device stepped back
      expect(clock.offset, const Duration(milliseconds: 875));
    },
  );

  test('MarketClockState.fromJson reads the welcome clock and ==', () {
    final json = {
      'phase': 'open',
      'marketOffsetMs': 3600000,
      'mode': 'demo',
      'overridden': true,
      'tradingDay': '2026-11-10',
      'nextPhaseAt': 1762422000000,
    };
    final a = MarketClockState.fromJson(json);
    expect(a.phase, MarketPhase.open);
    expect(a.marketNow(server), server.add(const Duration(hours: 1)));
    expect(a.nextPhaseAt!.millisecondsSinceEpoch, 1762422000000);
    expect(a, MarketClockState.fromJson(json));
    expect(a.copyWith(phase: MarketPhase.closed), isNot(a));
  });
}
