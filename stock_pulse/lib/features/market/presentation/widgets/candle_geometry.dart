import 'dart:math';

import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

/// Pure layout maths of the price chart: which candles fit, and where a
/// price or a slot lands in pixels.
abstract final class CandleGeometry {
  static const axisWidth = 64.0;
  static const timeAxisHeight = 16.0;
  static const maxCandleWidth = 28.0;
  static const fitMaxCandleWidth = 18.0;

  static double minCandleWidth(ChartType type) => isLine(type) ? 0.5 : 1.5;

  static bool isLine(ChartType type) =>
      type == ChartType.line || type == ChartType.area;

  /// Width that fits every candle in [plotWidth], within the limits.
  static double fitWidth(double plotWidth, int count, ChartType type) =>
      (plotWidth / max(1, count)).clamp(
        minCandleWidth(type),
        fitMaxCandleWidth,
      );

  static double anchoredOffset(
    int length,
    double plotWidth, {
    required double oldWidth,
    required double newWidth,
    required double offset,
    required double focalX,
  }) {
    final distance = (plotWidth - focalX.clamp(0, plotWidth));
    return (offset + distance / oldWidth - distance / newWidth).clamp(
      0,
      maxOffset(length, plotWidth, newWidth),
    );
  }

  /// Indexes [start, end) of the candles that fit in [plotWidth] when
  /// scrolled [offset] candles back from the newest.
  static (int, int) visibleRange(
    int length,
    double plotWidth,
    double candleWidth,
    int offset,
  ) {
    final count = (plotWidth / candleWidth).floor();
    final end = max(0, length - offset);
    return (max(0, end - count), end);
  }

  /// Largest scroll-back offset that still fills the plot.
  static double maxOffset(int length, double plotWidth, double candleWidth) =>
      max(0.0, length - plotWidth / candleWidth);

  /// Candle index under [dx], clamped to the visible range.
  static int indexAt(
    double dx,
    int length,
    double plotWidth,
    double candleWidth,
    int offset,
  ) {
    final (start, end) = visibleRange(length, plotWidth, candleWidth, offset);
    return (start + (dx / candleWidth).floor()).clamp(
      start,
      max(start, end - 1),
    );
  }

  /// Low and high of the price axis for [visible], padded by 8 %, so the
  /// [baseline] is always on screen.
  static (double, double) priceBounds(
    List<Candle> visible,
    ChartType type, {
    double? baseline,
  }) {
    final line = isLine(type);
    var hi = visible.map((c) => line ? c.close : c.high).reduce(max);
    var lo = visible.map((c) => line ? c.close : c.low).reduce(min);
    if (baseline != null) {
      hi = max(hi, baseline);
      lo = min(lo, baseline);
    }
    final pad = max((hi - lo) * 0.08, 0.05);
    return (lo - pad, hi + pad);
  }

  /// Time-axis text: clock times within a day, dates beyond, months
  /// beyond 400 days.
  static String axisLabel(DateTime t, Duration span, CandleInterval interval) {
    if (interval.isIntraday) {
      return span <= const Duration(days: 1)
          ? Fmt.shortTime(t)
          : Fmt.dayMonth(t);
    }
    return span > const Duration(days: 400)
        ? Fmt.monthYear(t)
        : Fmt.dayMonth(t);
  }
}
