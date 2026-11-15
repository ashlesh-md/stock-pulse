import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/market_time/domain/freshness.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/market_time/domain/server_clock.dart';

void main() {
  final server = DateTime.utc(2026, 11, 10, 5);
  const rtt = Duration(milliseconds: 20);

  void pingPong(ServerClock clock, FakeClock device, DateTime serverNow) {
    final sent = device.now().millisecondsSinceEpoch;
    device.advance(rtt);
    clock.onPong(
      sent,
      serverNow.add(rtt ~/ 2).millisecondsSinceEpoch,
      device.now(),
    );
  }

  ServerClock syncedWith(FakeClock device) {
    final clock = ServerClock(device)
      ..onWelcome(server.millisecondsSinceEpoch, device.now());
    for (var i = 0; i < 5; i++) {
      pingPong(clock, device, clock.now());
    }
    return clock;
  }

  Duration error(ServerClock clock, DateTime trueServerNow) =>
      clock.now().difference(trueServerNow).abs();

  for (final skew in [
    const Duration(seconds: 30),
    const Duration(seconds: -30),
  ]) {
    test('F8 a device clock ${skew.inSeconds} s off still reads server time '
        'and a fresh quote stays live', () {
      final device = FakeClock(server.add(skew));
      final clock = syncedWith(device);
      final trueNow = server.add(rtt * 5);

      expect(error(clock, trueNow), lessThan(const Duration(milliseconds: 15)));
      expect(
        freshnessOf(
          asOf: trueNow.subtract(const Duration(seconds: 1)),
          fromCache: false,
          serverNow: clock.now(),
          socketLive: true,
          phase: MarketPhase.open,
        ),
        Freshness.live,
      );
    });
  }

  for (final jump in [const Duration(hours: 1), const Duration(hours: -1)]) {
    test('F8 a device time change of ${jump.inMinutes} min while running '
        're-syncs at the next pong', () {
      final device = FakeClock(server);
      final clock = syncedWith(device);
      final trueNow = server.add(rtt * 5);

      device.advance(jump);
      final spanning = device.now().subtract(jump).millisecondsSinceEpoch;
      device.advance(rtt);
      clock.onPong(
        spanning,
        trueNow.add(rtt ~/ 2).millisecondsSinceEpoch,
        device.now(),
      );
      pingPong(clock, device, trueNow.add(rtt));

      expect(
        error(clock, trueNow.add(rtt * 2)),
        lessThan(const Duration(milliseconds: 15)),
      );
    });
  }
}
