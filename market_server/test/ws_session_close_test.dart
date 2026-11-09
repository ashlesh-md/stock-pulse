import 'dart:async';
import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A socket whose close handshake never finishes (a half-open peer).
class _HungSink implements WebSocketSink {
  final sent = <Object?>[];
  int closeCalls = 0;

  @override
  void add(Object? data) => sent.add(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) {
    closeCalls++;
    return Completer<void>().future;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HungChannel implements WebSocketChannel {
  // ignore: close_sinks, the peer never sends; the test ends with it open.
  final input = StreamController<Object?>();
  @override
  // ignore: close_sinks, its close never completes by design.
  final _HungSink sink = _HungSink();

  @override
  Stream<Object?> get stream => input.stream;

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeMarketClock clock;
  late WsGateway gateway;

  setUp(() {
    clock = FakeMarketClock(
      wallStart: DateTime.utc(2026, 11),
      marketStart: DateTime.utc(2026, 11, 10, 5),
    );
    final engine = MarketEngine(
      instruments,
      random: Random(1),
      clock: clock.marketNow,
      intradayDays: 0,
      dailyDays: 0,
    );
    gateway = WsGateway(
      engine,
      Broker(engine),
      clock: clock,
      calendar: MarketCalendar(holidays: const {}, holidaySourceDate: 't'),
      closeTimeout: const Duration(milliseconds: 20),
    );
  });

  test('an idle half-open session is dropped at once and closed once', () {
    final channel = _HungChannel();
    gateway.connect(channel);
    expect(gateway.connectionCount, 1);

    clock.advance(gateway.idleTimeout + const Duration(seconds: 1));
    gateway.idleCheckNow();
    expect(gateway.connectionCount, 0);

    gateway.idleCheckNow();
    expect(channel.sink.closeCalls, 1);
  });

  test('shutdown closes hung sessions together within the timeout', () async {
    final channels = [_HungChannel(), _HungChannel(), _HungChannel()];
    channels.forEach(gateway.connect);

    final watch = Stopwatch()..start();
    await gateway.close();
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)));
    expect(gateway.connectionCount, 0);
    for (final c in channels) {
      expect(c.sink.closeCalls, 1);
    }
  });
}
