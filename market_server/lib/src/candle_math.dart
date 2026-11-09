import 'dart:math';

import 'package:market_server/src/models.dart';
import 'package:market_server/src/stock_state.dart';
import 'package:market_server/src/time_buckets.dart';

double roundToTick(double price, double tick) =>
    round2((price / tick).round() * tick);

double round2(double v) => (v * 100).roundToDouble() / 100;

/// Standard normal sample (Box–Muller).
double gaussian(Random random) {
  final u1 = 1 - random.nextDouble();
  final u2 = random.nextDouble();
  return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
}

void addToCandles(
  List<Candle> candles,
  DateTime bucket,
  double price,
  int qty, {
  int? cap,
}) {
  if (candles.isEmpty || candles.last.start != bucket) {
    candles.add(
      Candle(
        start: bucket,
        open: price,
        high: price,
        low: price,
        close: price,
        volume: qty,
      ),
    );
    if (cap != null && candles.length > cap) candles.removeAt(0);
  } else {
    candles.last.add(price, qty);
  }
}

/// [stock]'s candles at [interval] (1m, 5m, 15m, 1h, 1d, 1w), oldest
/// first, whose bucket starts in [from, to]. At most the newest [limit].
List<Candle> aggregateCandles(
  StockState stock,
  Duration interval, {
  required int limit,
  DateTime? from,
  DateTime? to,
}) {
  final daily = interval.inDays >= 1;
  final source = daily ? stock.daily : stock.minutes;
  final base = daily ? const Duration(days: 1) : const Duration(minutes: 1);

  final out = <Candle>[];
  for (final c in source) {
    final bucket = interval == base ? c.start : bucketStart(c.start, interval);
    if (from != null && bucket.isBefore(from)) continue;
    if (to != null && bucket.isAfter(to)) break;
    if (out.isEmpty || out.last.start != bucket) {
      out.add(
        Candle(
          start: bucket,
          open: c.open,
          high: c.high,
          low: c.low,
          close: c.close,
          volume: c.volume,
        ),
      );
    } else {
      out.last
        ..high = max(out.last.high, c.high)
        ..low = min(out.last.low, c.low)
        ..close = c.close
        ..volume += c.volume;
    }
  }
  return out.length > limit ? out.sublist(out.length - limit) : out;
}
