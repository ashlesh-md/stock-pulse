import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:test/test.dart';

import 'support/engine_fixture.dart';

void main() {
  group('bucketStart (IST-aligned)', () {
    test('minutes and hours', () {
      final t = DateTime.utc(2026, 11, 4, 9, 37, 42); // 15:07:42 IST
      expect(
        bucketStart(t, const Duration(minutes: 1)),
        DateTime.utc(2026, 11, 4, 9, 37),
      );
      expect(
        bucketStart(t, const Duration(minutes: 5)),
        DateTime.utc(2026, 11, 4, 9, 35),
      );
      expect(
        bucketStart(t, const Duration(minutes: 15)),
        DateTime.utc(2026, 11, 4, 9, 30),
      );
      // 1h starts on the IST hour: 15:00 IST = 09:30 UTC.
      expect(
        bucketStart(t, const Duration(hours: 1)),
        DateTime.utc(2026, 11, 4, 9, 30),
      );
    });

    test('day starts at IST midnight, week on Monday IST', () {
      expect(bucketStart(now, const Duration(days: 1)), todayIst);
      // 4 Nov 2026 is a Wednesday → week starts Mon 2 Nov 00:00 IST.
      expect(
        bucketStart(now, const Duration(days: 7)),
        DateTime.utc(2026, 11, 1, 18, 30),
      );
      // 00:10 IST on 5 Nov is already the next day.
      expect(
        bucketStart(DateTime.utc(2026, 11, 4, 18, 40), const Duration(days: 1)),
        DateTime.utc(2026, 11, 4, 18, 30),
      );
    });
  });

  group('MarketEngine history', () {
    test(
      'minute candles from IST midnight 2 days ago to the last full minute',
      () {
        final candles = seededEngine().candles(
          'TCS',
          const Duration(minutes: 1),
          limit: 100000,
        );
        expect(candles.first.start, todayIst.subtract(const Duration(days: 2)));
        expect(candles.last.start, DateTime.utc(2026, 11, 4, 9, 29));
        for (final c in candles) {
          expect(c.high, greaterThanOrEqualTo(max(c.open, c.close)));
          expect(c.low, lessThanOrEqualTo(min(c.open, c.close)));
        }
      },
    );

    test('latest price is the instrument base price', () {
      final tcs = seededEngine()['TCS']!;
      expect(tcs.ltp, closeTo(tcs.instrument.basePrice, 0.05));
    });

    test(
      'daily: years of history, then the intraday days, last one is today',
      () {
        final stock = seededEngine()['INFY']!;
        expect(stock.daily, hasLength(400 + 3)); // 400 old + 2 full + today
        expect(stock.today.start, todayIst);
        expect(stock.prevClose, stock.daily[stock.daily.length - 2].close);

        // Today's daily candle agrees with today's minutes.
        final todayMinutes = stock.minutes
            .where((m) => !m.start.isBefore(todayIst))
            .toList();
        expect(stock.open, todayMinutes.first.open);
        expect(stock.high, todayMinutes.map((m) => m.high).reduce(max));
        expect(stock.volume, todayMinutes.fold<int>(0, (s, m) => s + m.volume));
      },
    );

    test('5m merges five 1m candles', () {
      final engine = seededEngine();
      final one = engine.candles(
        'INFY',
        const Duration(minutes: 1),
        limit: 100000,
      );
      final five = engine.candles(
        'INFY',
        const Duration(minutes: 5),
        limit: 100000,
      );
      final start = DateTime.utc(2026, 11, 4, 8, 30);
      final parts = one
          .where(
            (c) =>
                !c.start.isBefore(start) &&
                c.start.isBefore(start.add(const Duration(minutes: 5))),
          )
          .toList();
      final merged = five.firstWhere((c) => c.start == start);
      expect(parts, hasLength(5));
      expect(merged.open, parts.first.open);
      expect(merged.close, parts.last.close);
      expect(merged.high, parts.map((c) => c.high).reduce(max));
      expect(merged.volume, parts.fold<int>(0, (s, c) => s + c.volume));
    });

    test('weekly candles start on Monday IST and merge daily ones', () {
      final engine = seededEngine();
      final weeks = engine.candles(
        'SBIN',
        const Duration(days: 7),
        limit: 100000,
      );
      for (final w in weeks) {
        final ist = w.start.add(istOffset);
        expect(ist.weekday, DateTime.monday);
        expect([ist.hour, ist.minute], [0, 0]);
      }
      expect(weeks.last.close, engine['SBIN']!.today.close);
    });

    test('from / to / limit select a window', () {
      final engine = seededEngine();
      final from = todayIst.subtract(const Duration(days: 30));
      final month = engine.candles('LT', const Duration(days: 1), from: from);
      expect(month.first.start, from);
      expect(month, hasLength(31)); // 30 days + today
      final last3 = engine.candles('LT', const Duration(days: 1), limit: 3);
      expect(last3.last.start, todayIst);
      expect(last3, hasLength(3));
    });
  });

  group('MarketEngine live', () {
    test('step moves prices on the tick grid and emits changed symbols', () {
      final engine = seededEngine();
      final emitted = <Set<String>>[];
      engine.ticks.listen(emitted.add);
      for (var i = 0; i < 5; i++) {
        engine.step();
      }
      expect(emitted, isNotEmpty);
      for (final s in engine.stocks) {
        final ticks = s.ltp / s.instrument.tickSize;
        expect(
          (ticks - ticks.round()).abs(),
          lessThan(1e-6),
          reason: s.instrument.symbol,
        );
        // S-6: the NIFTY index has no order book.
        if (s.instrument.tradable) expect(s.bestAsk, greaterThan(s.bestBid));
        expect(s.today.close, s.ltp);
      }
    });

    test(
      'a trade after IST midnight starts a new day: prevClose rolls over',
      () {
        var clock = DateTime.utc(2026, 11, 4, 18, 29, 50); // 23:59:50 IST
        final engine = seededEngine(clock: () => clock);
        final itc = engine['ITC']!;
        while (itc.lastTradeTime != clock) {
          engine.step();
        }
        final lastPriceOfDay = itc.ltp;
        final days = itc.daily.length;

        clock = DateTime.utc(2026, 11, 4, 18, 30, 5); // 00:00:05 IST, next day
        while (itc.lastTradeTime != clock) {
          engine.step();
        }
        expect(itc.daily, hasLength(days + 1));
        expect(itc.prevClose, lastPriceOfDay);
        expect(
          itc.volume,
          itc.lastQuantity,
          reason: 'new day starts from zero volume',
        );
      },
    );

    test('quote modes add fields: ltp < quote < full', () {
      final engine = seededEngine();
      final s = engine['SBIN']!;
      final ltp = engine.quoteJson(s, FeedMode.ltp);
      final quote = engine.quoteJson(s, FeedMode.quote);
      final full = engine.quoteJson(s, FeedMode.full);
      expect(ltp.keys, containsAll(['s', 'ltp', 'ch', 'chp', 't']));
      expect(ltp.containsKey('o'), isFalse);
      expect(quote.keys, containsAll(['o', 'h', 'l', 'pc', 'v', 'bid', 'ask']));
      expect(quote.containsKey('depth'), isFalse);
      expect((full['depth']! as Map)['bids'], hasLength(5));
    });
  });
}
