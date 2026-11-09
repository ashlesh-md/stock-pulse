import 'dart:math';

import 'package:market_server/src/candle_math.dart';
import 'package:market_server/src/models.dart';
import 'package:market_server/src/stock_state.dart';
import 'package:market_server/src/time_buckets.dart';

/// Builds the history charts need on first open:
///
/// 1. 1-minute candles from IST midnight [intradayDays] days ago up to now,
///    scaled so the latest close is the instrument's base price.
/// 2. Older daily candles for [dailyDays] days before that, scaled so they
///    end exactly where the minute history starts.
/// 3. Daily candles for the minute window, aggregated from the minutes, so
///    the 1D chart and the daily chart always agree.
void seedHistory(
  StockState stock, {
  required DateTime now,
  required Random random,
  required int intradayDays,
  required int dailyDays,
}) {
  final tick = stock.instrument.tickSize;
  final thisMinute = bucketStart(now, const Duration(minutes: 1));
  final windowStart = bucketStart(
    now,
    const Duration(days: 1),
  ).subtract(Duration(days: intradayDays));

  // 1. Minutes: ~0.04% per minute ≈ 1.5% per day, like a large-cap stock.
  final minuteCount = thisMinute.difference(windowStart).inMinutes;
  final path = <(double, double, double, double)>[];
  var p = 1.0;
  for (var i = 0; i < minuteCount; i++) {
    final o = p;
    var h = o, l = o;
    for (var k = 0; k < 4; k++) {
      p *= 1 + 0.0002 * gaussian(random);
      h = max(h, p);
      l = min(l, p);
    }
    path.add((o, h, l, p));
  }
  final minuteScale =
      stock.instrument.basePrice / (path.isEmpty ? 1 : path.last.$4);
  for (var i = 0; i < path.length; i++) {
    final (o, h, l, c) = path[i];
    stock.minutes.add(
      Candle(
        start: windowStart.add(Duration(minutes: i)),
        open: roundToTick(o * minuteScale, tick),
        high: roundToTick(h * minuteScale, tick),
        low: roundToTick(l * minuteScale, tick),
        close: roundToTick(c * minuteScale, tick),
        volume: 500 + random.nextInt(20000),
      ),
    );
  }
  final firstOpen = stock.minutes.isEmpty
      ? stock.instrument.basePrice
      : stock.minutes.first.open;

  // 2. Older days: ~10%/year drift, ~1.5% daily moves, small opening gaps.
  final days = <(double, double, double, double)>[];
  var d = 1.0;
  for (var i = 0; i < dailyDays; i++) {
    final o = d * (1 + 0.003 * gaussian(random));
    final c = o * (1 + 0.0004 + 0.015 * gaussian(random));
    final h = max(o, c) * (1 + 0.006 * gaussian(random).abs());
    final l = min(o, c) * (1 - 0.006 * gaussian(random).abs());
    days.add((o, h, l, c));
    d = c;
  }
  final dayScale = firstOpen / (days.isEmpty ? 1 : days.last.$4);
  for (var i = 0; i < days.length; i++) {
    final (o, h, l, c) = days[i];
    stock.daily.add(
      Candle(
        start: windowStart.subtract(Duration(days: dailyDays - i)),
        open: roundToTick(o * dayScale, tick),
        high: roundToTick(h * dayScale, tick),
        low: roundToTick(l * dayScale, tick),
        close: roundToTick(c * dayScale, tick),
        volume: 2000000 + random.nextInt(20000000),
      ),
    );
  }

  // 3. Days covered by minutes (the last one is today, still open).
  for (final m in stock.minutes) {
    addToCandles(
      stock.daily,
      bucketStart(m.start, const Duration(days: 1)),
      m.open,
      0,
    );
    stock.daily.last
      ..high = max(stock.daily.last.high, m.high)
      ..low = min(stock.daily.last.low, m.low)
      ..close = m.close
      ..volume += m.volume;
  }
  if (stock.daily.isEmpty) {
    final p0 = stock.instrument.basePrice;
    stock.daily.add(
      Candle(
        start: bucketStart(now, const Duration(days: 1)),
        open: p0,
        high: p0,
        low: p0,
        close: p0,
        volume: 0,
      ),
    );
  }
  stock.ltp = stock.minutes.isEmpty
      ? stock.instrument.basePrice
      : stock.minutes.last.close;
}
