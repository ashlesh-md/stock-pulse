import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:market_server/src/account_book.dart';
import 'package:test/test.dart';

void main() {
  test(
    'above alert triggers once on a live crossing, never while closed',
    () async {
      const today = IstDate(2026, 11, 10);
      const tomorrow = IstDate(2026, 11, 11);
      final clock = FakeMarketClock(
        wallStart: DateTime.utc(2026, 11, 10, 11),
        marketStart: Ist.at(today, 16, 0),
      );
      final engine = MarketEngine(
        instruments,
        random: Random(7),
        marketClock: clock,
        calendar: MarketCalendar(holidays: const {}, holidaySourceDate: 'test'),
        intradayDays: 1,
        dailyDays: 2,
      );
      final account = AccountBook(engine, clock: clock.marketNow);
      addTearDown(account.close);
      addTearDown(engine.stop);

      final events = <Map<String, Object?>>[];
      account.events.listen((event) {
        if (event.$1 == 'alert') events.add(event.$2);
      });
      final stock = engine['TCS']!;
      final tick = stock.instrument.tickSize;
      final level = ((stock.ltp + 1) / tick).ceil() * tick;
      final alert = account.createAlert('TCS', 'above', level);
      events.clear();

      stock.ltp = level + tick;
      engine.step();
      expect(events, isEmpty);
      expect(account.alerts.single['status'], 'active');

      clock.jumpTo(Ist.at(tomorrow, 10, 0));
      account.evaluateAlerts();
      account.evaluateAlerts();

      expect(events, hasLength(1));
      expect(events.single['alertId'], alert['alertId']);
      expect(events.single['status'], 'triggered');
      expect(
        DateTime.tryParse(events.single['triggeredAt']! as String),
        isNotNull,
      );
      expect(account.alerts.single['status'], 'triggered');
    },
  );
}
