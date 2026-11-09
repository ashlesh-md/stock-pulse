import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 4, 10, 5);
  final base = [
    Candle(start: t0, open: 100, high: 101, low: 99, close: 100.5, volume: 10),
  ];

  test('bucketOf floors the time to the interval', () {
    final t = DateTime.utc(2026, 11, 4, 10, 7, 42);
    expect(CandleInterval.m1.bucketOf(t), DateTime.utc(2026, 11, 4, 10, 7));
    expect(CandleInterval.m5.bucketOf(t), DateTime.utc(2026, 11, 4, 10, 5));
    expect(CandleInterval.m15.bucketOf(t), DateTime.utc(2026, 11, 4, 10));
  });

  test('a trade in the same bucket updates high/low/close/volume', () {
    final out = applyTrade(
      base,
      CandleInterval.m5,
      price: 102,
      time: t0.add(const Duration(minutes: 3)),
      volumeDelta: 5,
    );
    expect(out, hasLength(1));
    expect(
      out.last,
      Candle(start: t0, open: 100, high: 102, low: 99, close: 102, volume: 15),
    );
    expect(
      identical(out, base),
      isFalse,
      reason: 'returns a new list (immutable state)',
    );
    expect(base.last.close, 100.5, reason: 'input untouched');
  });

  test('a trade in the next bucket opens a new candle', () {
    final out = applyTrade(
      base,
      CandleInterval.m5,
      price: 98,
      time: t0.add(const Duration(minutes: 5, seconds: 1)),
      volumeDelta: 3,
    );
    expect(out, hasLength(2));
    expect(
      out.last,
      Candle(
        start: DateTime.utc(2026, 11, 4, 10, 10),
        open: 98,
        high: 98,
        low: 98,
        close: 98,
        volume: 3,
      ),
    );
  });

  test('a late trade from an older bucket is ignored', () {
    final out = applyTrade(
      base,
      CandleInterval.m1,
      price: 50,
      time: t0.subtract(const Duration(minutes: 2)),
      volumeDelta: 1,
    );
    expect(identical(out, base), isTrue);
  });

  test('keeps at most maxCandles', () {
    var candles = <Candle>[];
    for (var i = 0; i < 10; i++) {
      candles = applyTrade(
        candles,
        CandleInterval.m1,
        price: 1,
        time: t0.add(Duration(minutes: i)),
        volumeDelta: 1,
        maxCandles: 4,
      );
    }
    expect(candles, hasLength(4));
    expect(candles.first.start, t0.add(const Duration(minutes: 6)));
  });

  group('IST buckets for days and weeks', () {
    // 09:30 UTC on Wed 4 Nov 2026 = 15:00 IST.
    final t = DateTime.utc(2026, 11, 4, 9, 30);

    test('a day starts at IST midnight (18:30 UTC the day before)', () {
      expect(CandleInterval.d1.bucketOf(t), DateTime.utc(2026, 11, 3, 18, 30));
      expect(
        CandleInterval.d1.bucketOf(DateTime.utc(2026, 11, 4, 18, 31)),
        DateTime.utc(2026, 11, 4, 18, 30),
      );
    });

    test('a week starts on Monday 00:00 IST', () {
      final monday = CandleInterval.w1.bucketOf(t);
      expect(monday, DateTime.utc(2026, 11, 1, 18, 30));
      expect(monday.add(istOffset).weekday, DateTime.monday);
    });

    test('1h buckets start on the IST hour', () {
      expect(
        CandleInterval.h1.bucketOf(DateTime.utc(2026, 11, 4, 9, 10)),
        DateTime.utc(2026, 11, 4, 8, 30),
      );
    });
  });

  group('ChartRange', () {
    final now = DateTime.utc(2026, 11, 4, 9, 30);
    test('1D starts at IST midnight; others count back', () {
      expect(ChartRange.d1.from(now), DateTime.utc(2026, 11, 3, 18, 30));
      expect(ChartRange.w1.from(now), now.subtract(const Duration(days: 7)));
      expect(ChartRange.y1.from(now), now.subtract(const Duration(days: 365)));
    });

    test('every default interval is one of the allowed ones', () {
      for (final r in ChartRange.values) {
        expect(r.intervals, contains(r.defaultInterval), reason: r.label);
      }
    });
  });

  group('heikinAshi', () {
    test('averages each candle with the previous HA candle', () {
      final t = DateTime.utc(2026);
      final ha = heikinAshi([
        Candle(start: t, open: 10, high: 14, low: 8, close: 12, volume: 1),
        Candle(
          start: t.add(const Duration(days: 1)),
          open: 12,
          high: 16,
          low: 11,
          close: 15,
          volume: 2,
        ),
      ]);
      // first: close = (10+14+8+12)/4 = 11, open = (10+12)/2 = 11
      expect([ha[0].open, ha[0].close, ha[0].high, ha[0].low], [11, 11, 14, 8]);
      // second: close = (12+16+11+15)/4 = 13.5, open = (11+11)/2 = 11
      expect(
        [ha[1].open, ha[1].close, ha[1].high, ha[1].low],
        [11, 13.5, 16, 11],
      );
      expect(ha[1].volume, 2, reason: 'volume is unchanged');
    });

    test('empty in, empty out', () => expect(heikinAshi(const []), isEmpty));
  });
}
