import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

@immutable
class StockDetailState {
  const StockDetailState({
    required this.instrument,
    required this.quote,
    required this.range,
    required this.interval,
    required this.candles,
    this.chartType = ChartType.candles,
    this.loadingCandles = false,
    this.candlesFailed = false,
  });

  final Instrument instrument;
  final Quote quote;

  /// How far back the chart looks (1D … 5Y) and the candle size inside it.
  final ChartRange range;
  final CandleInterval interval;
  final ChartType chartType;

  /// Candles for [range] at [interval], oldest first. The last one is live.
  final List<Candle> candles;

  /// True while another range/interval loads (the old chart stays shown).
  final bool loadingCandles;

  /// The last range or interval change failed; the old chart stays.
  final bool candlesFailed;

  /// Price the range's performance is measured from. 1D compares with
  /// yesterday's close (like the change shown everywhere else); longer
  /// ranges with the first candle's open.
  double? get rangeBase => range == ChartRange.d1
      ? quote.prevClose ?? candles.firstOrNull?.open
      : candles.firstOrNull?.open;

  double? get rangeChange => rangeBase == null ? null : quote.ltp - rangeBase!;
  double? get rangeChangePercent => rangeBase == null || rangeBase == 0
      ? null
      : rangeChange! / rangeBase! * 100;
  double? get rangeHigh =>
      candles.isEmpty ? null : candles.map((c) => c.high).reduce(max);
  double? get rangeLow =>
      candles.isEmpty ? null : candles.map((c) => c.low).reduce(min);

  StockDetailState copyWith({
    Instrument? instrument,
    Quote? quote,
    ChartRange? range,
    CandleInterval? interval,
    ChartType? chartType,
    List<Candle>? candles,
    bool? loadingCandles,
    bool? candlesFailed,
  }) => StockDetailState(
    instrument: instrument ?? this.instrument,
    quote: quote ?? this.quote,
    range: range ?? this.range,
    interval: interval ?? this.interval,
    chartType: chartType ?? this.chartType,
    candles: candles ?? this.candles,
    loadingCandles: loadingCandles ?? this.loadingCandles,
    candlesFailed: candlesFailed ?? this.candlesFailed,
  );
}
