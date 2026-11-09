import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

void main() {
  test('Candle.fromJson reads the short wire keys', () {
    final c = Candle.fromJson({
      't': 0,
      'o': 1,
      'h': 3,
      'l': 0.5,
      'c': 2,
      'v': 7,
    });
    expect(
      c,
      Candle(
        start: DateTime.utc(1970),
        open: 1,
        high: 3,
        low: 0.5,
        close: 2,
        volume: 7,
      ),
    );
    expect(c.isUp, isTrue);
    expect(c.copyWith(close: 0.8).isUp, isFalse);
  });

  test('Candle copyWith and equality', () {
    final c = Candle(
      start: DateTime.utc(2026),
      open: 1,
      high: 2,
      low: 1,
      close: 2,
      volume: 1,
    );
    final moved = c.copyWith(high: 4, low: 0.5, volume: 9);
    expect(
      (moved.high, moved.low, moved.close, moved.volume),
      (4.0, 0.5, 2.0, 9),
    );
    expect(c.copyWith(), c);
    expect(c.copyWith().hashCode, c.hashCode);
    expect(moved, isNot(c));
  });

  test('only sub-day intervals are intraday', () {
    expect(CandleInterval.h1.isIntraday, isTrue);
    expect(CandleInterval.d1.isIntraday, isFalse);
  });

  test('the 5Y range starts five years back', () {
    final now = DateTime.utc(2026, 11, 10);
    expect(
      ChartRange.y5.from(now),
      now.subtract(const Duration(days: 5 * 365)),
    );
  });

  test('instruments are equal by id', () {
    Instrument parse(String name) => Instrument.fromJson({
      'id': 'TCS',
      'name': name,
      'tickSize': 0.05,
      'lotSize': 1,
    });
    expect(parse('a'), parse('b'));
    expect(parse('a').hashCode, parse('b').hashCode);
    expect(parse('a').id, 'TCS');
  });

  test('depth levels compare by value', () {
    final a = DepthLevel.fromJson({'p': 1, 'q': 2, 'n': 3});
    expect(a, DepthLevel.fromJson({'p': 1, 'q': 2, 'n': 3}));
    expect(a.hashCode, DepthLevel.fromJson({'p': 1, 'q': 2, 'n': 3}).hashCode);
  });

  test('a quote is up from zero change and exposes changePct', () {
    final q = Quote(
      symbol: 'TCS',
      ltp: 10,
      change: 0,
      changePercent: 0.5,
      lastTradeTime: DateTime.utc(2026),
    );
    expect(q.isUp, isTrue);
    expect(q.changePct, 0.5);
  });
}
