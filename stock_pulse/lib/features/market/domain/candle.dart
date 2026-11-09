/// One OHLCV bar. Immutable: a live update creates a new [Candle].
class Candle {
  const Candle({
    required this.start,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory Candle.fromJson(Map<String, Object?> json) => Candle(
    start: DateTime.fromMillisecondsSinceEpoch(json['t']! as int, isUtc: true),
    open: (json['o']! as num).toDouble(),
    high: (json['h']! as num).toDouble(),
    low: (json['l']! as num).toDouble(),
    close: (json['c']! as num).toDouble(),
    volume: json['v']! as int,
  );

  final DateTime start;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;

  /// Green candle: closed at or above where it opened.
  bool get isUp => close >= open;

  Candle copyWith({double? high, double? low, double? close, int? volume}) =>
      Candle(
        start: start,
        open: open,
        high: high ?? this.high,
        low: low ?? this.low,
        close: close ?? this.close,
        volume: volume ?? this.volume,
      );

  @override
  bool operator ==(Object other) =>
      other is Candle &&
      other.start == start &&
      other.open == open &&
      other.high == high &&
      other.low == low &&
      other.close == close &&
      other.volume == volume;

  @override
  int get hashCode => Object.hash(start, open, high, low, close, volume);
}

/// Indian Standard Time is UTC+05:30 all year.
const istOffset = Duration(hours: 5, minutes: 30);

/// Candle sizes the server supports.
enum CandleInterval {
  m1('1m', 'minute', Duration(minutes: 1)),
  m5('5m', '5 minutes', Duration(minutes: 5)),
  m15('15m', '15 minutes', Duration(minutes: 15)),
  h1('1h', 'hour', Duration(hours: 1)),
  d1('1d', 'day', Duration(days: 1)),
  w1('1w', 'week', Duration(days: 7));

  const CandleInterval(this.apiName, this.label, this.duration);
  final String apiName;
  final String label;
  final Duration duration;

  bool get isIntraday => duration < const Duration(days: 1);

  /// Start of the bucket [time] falls in, aligned to IST like Indian
  /// brokers: 10:07:42 at 5m → 10:05:00; a day starts at IST midnight; a
  /// week on Monday 00:00 IST. Same rule as the server's `bucketStart`.
  DateTime bucketOf(DateTime time) {
    const dayMs = 86400000;
    final off = istOffset.inMilliseconds;
    final ms = time.millisecondsSinceEpoch + off;
    final int start;
    if (this == CandleInterval.w1) {
      // 1970-01-01 was a Thursday; Monday is 3 days earlier.
      start = ((ms ~/ dayMs + 3) ~/ 7 * 7 - 3) * dayMs;
    } else {
      final size = duration.inMilliseconds;
      start = ms ~/ size * size;
    }
    return DateTime.fromMillisecondsSinceEpoch(start - off, isUtc: true);
  }
}

/// How far back the chart looks, like the 1D … 5Y buttons on Kite or Groww.
/// Each range allows a few intervals that give a readable number of candles.
enum ChartRange {
  d1('1D', [
    CandleInterval.m1,
    CandleInterval.m5,
    CandleInterval.m15,
  ], CandleInterval.m5),
  w1('1W', [
    CandleInterval.m5,
    CandleInterval.m15,
    CandleInterval.h1,
  ], CandleInterval.m15),
  m1('1M', [CandleInterval.d1], CandleInterval.d1),
  m3('3M', [CandleInterval.d1], CandleInterval.d1),
  m6('6M', [CandleInterval.d1, CandleInterval.w1], CandleInterval.d1),
  y1('1Y', [CandleInterval.d1, CandleInterval.w1], CandleInterval.d1),
  y5('5Y', [CandleInterval.d1, CandleInterval.w1], CandleInterval.w1);

  const ChartRange(this.label, this.intervals, this.defaultInterval);
  final String label;
  final List<CandleInterval> intervals;
  final CandleInterval defaultInterval;

  /// First instant the range covers. 1D = since IST midnight (today's
  /// session); the others count back from [now].
  DateTime from(DateTime now) => switch (this) {
    ChartRange.d1 => CandleInterval.d1.bucketOf(now),
    ChartRange.w1 => now.subtract(const Duration(days: 7)),
    ChartRange.m1 => now.subtract(const Duration(days: 30)),
    ChartRange.m3 => now.subtract(const Duration(days: 91)),
    ChartRange.m6 => now.subtract(const Duration(days: 182)),
    ChartRange.y1 => now.subtract(const Duration(days: 365)),
    ChartRange.y5 => now.subtract(const Duration(days: 5 * 365)),
  };
}

/// Ways to draw the same OHLC data.
enum ChartType {
  candles('Candles'),
  heikinAshi('Heikin-Ashi'),
  ohlc('OHLC bars'),
  line('Line'),
  area('Area');

  const ChartType(this.label);
  final String label;
}

/// Heikin-Ashi ("average bar") candles: a smoothed version that makes trends
/// easier to see. Each HA candle uses the previous HA candle:
///
/// - close = (open + high + low + close) / 4
/// - open  = (previous HA open + previous HA close) / 2   (first: (o + c) / 2)
/// - high  = max(high, HA open, HA close)
/// - low   = min(low, HA open, HA close)
///
/// HA prices are averages, not real trade prices: never use them for P&L.
List<Candle> heikinAshi(List<Candle> candles) {
  final out = <Candle>[];
  for (final c in candles) {
    final close = (c.open + c.high + c.low + c.close) / 4;
    final open = out.isEmpty
        ? (c.open + c.close) / 2
        : (out.last.open + out.last.close) / 2;
    out.add(
      Candle(
        start: c.start,
        open: open,
        high: [c.high, open, close].reduce((a, b) => a > b ? a : b),
        low: [c.low, open, close].reduce((a, b) => a < b ? a : b),
        close: close,
        volume: c.volume,
      ),
    );
  }
  return out;
}

/// Folds one live trade into a candle list (oldest first) and returns a NEW
/// list. This is how every trading chart works: history comes from REST once,
/// then the app keeps the newest candle current from the tick stream.
///
/// - Trade in the same bucket as the last candle: update its high, low,
///   close and volume.
/// - Trade in a later bucket: start a new candle at the trade price.
/// - Trade older than the last candle (a late message): ignore it.
List<Candle> applyTrade(
  List<Candle> candles,
  CandleInterval interval, {
  required double price,
  required DateTime time,
  required int volumeDelta,
  int maxCandles = 2500,
}) {
  final bucket = interval.bucketOf(time);
  if (candles.isNotEmpty) {
    final last = candles.last;
    if (bucket.isBefore(last.start)) return candles;
    if (bucket == last.start) {
      final updated = last.copyWith(
        high: price > last.high ? price : last.high,
        low: price < last.low ? price : last.low,
        close: price,
        volume: last.volume + volumeDelta,
      );
      return [...candles.sublist(0, candles.length - 1), updated];
    }
  }
  final next = Candle(
    start: bucket,
    open: price,
    high: price,
    low: price,
    close: price,
    volume: volumeDelta,
  );
  final grown = [...candles, next];
  return grown.length > maxCandles
      ? grown.sublist(grown.length - maxCandles)
      : grown;
}
