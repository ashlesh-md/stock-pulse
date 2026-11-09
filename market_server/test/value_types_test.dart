import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:test/test.dart';

final cal = MarketCalendar(holidays: const {}, holidaySourceDate: 'test');
const tue = IstDate(2026, 11, 10);
const sat = IstDate(2026, 11, 14);

void main() {
  test('a boundary event names its kind, day and fast-forward', () {
    final e = BoundaryEvent(
      BoundaryKind.dayRoll,
      tue,
      Ist.at(tue, 9, 0),
      fastForward: true,
    );
    expect('$e', 'BoundaryEvent(dayRoll@2026-11-10, ff)');
    expect(
      '${BoundaryEvent(BoundaryKind.open, tue, Ist.at(tue, 9, 15))}',
      'BoundaryEvent(open@2026-11-10)',
    );
  });

  test('listed expiries are equal by date and kind', () {
    ListedExpiry at(int hour, ExpiryKind kind) =>
        ListedExpiry(date: tue, expiryAt: Ist.at(tue, hour, 0), kind: kind);
    expect(at(15, ExpiryKind.weekly), at(16, ExpiryKind.weekly));
    expect(
      at(15, ExpiryKind.weekly).hashCode,
      at(16, ExpiryKind.weekly).hashCode,
    );
    expect(at(15, ExpiryKind.weekly), isNot(at(15, ExpiryKind.monthly)));
    expect(
      '${at(15, ExpiryKind.monthly)}',
      'ListedExpiry(2026-11-10, monthly)',
    );
  });

  test('Ist.iso prints IST wall time with the +05:30 offset', () {
    expect(Ist.iso(Ist.at(tue, 9, 5, 7, 42)), '2026-11-10T09:05:07.042+05:30');
  });

  test('clockJson reports the previous trading day on a weekend', () {
    final clock = FakeMarketClock(
      wallStart: DateTime.utc(2026, 11),
      marketStart: Ist.at(sat, 11, 0),
    );
    expect(clockJson(clock, cal)['tradingDay'], '2026-11-13');
  });

  test('a real clock waits wall time and closes its jump stream', () async {
    final clock = MarketClock(mode: ClockMode.real);
    final watch = Stopwatch()..start();
    await clock.delay(const Duration(milliseconds: 20));
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(20));
    final done = clock.jumps.toList();
    await clock.close();
    expect(await done, isEmpty);
  });

  test('closing a position to flat resets its average price', () {
    final p = Position('X')
      ..apply(OrderSide.buy, 10, 100)
      ..apply(OrderSide.sell, 10, 110);
    expect(p.quantity, 0);
    expect(p.averagePrice, 0);
    expect(p.realizedPnl, 100);
  });

  test('a sell limit at or below the best bid fills at the bid', () {
    final engine = MarketEngine(
      instruments,
      random: Random(2),
      clock: () => DateTime.utc(2026, 11, 10, 6),
      intradayDays: 1,
      dailyDays: 5,
    );
    final tcs = engine['TCS']!;
    final order = Broker(engine).place(
      symbol: 'TCS',
      side: OrderSide.sell,
      type: OrderType.limit,
      quantity: 1,
      limitPrice: tcs.bestBid,
    );
    expect(order.status, OrderStatus.complete);
    expect(order.averagePrice, tcs.bestBid);
  });
}
