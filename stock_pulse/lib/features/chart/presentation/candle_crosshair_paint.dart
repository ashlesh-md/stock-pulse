import 'package:flutter/painting.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/strings/market_strings.dart';
import 'package:stock_pulse/features/chart/presentation/chart_paint_text.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

/// The crosshair's vertical line at [x] and its readout in the top-left
/// corner: time, OHLC (or close for line charts) and volume of [candle].
void paintCandleCrosshair(
  Canvas canvas, {
  required Candle candle,
  required double x,
  required double bottom,
  required CandleInterval interval,
  required bool isLine,
  required TextStyle style,
  required Color background,
  required MarketStrings strings,
}) {
  final line = Paint()
    ..color = style.color!.withValues(alpha: 0.6)
    ..strokeWidth = 0.7;
  canvas.drawLine(Offset(x, 0), Offset(x, bottom), line);
  final when = interval.isIntraday
      ? Fmt.dayTime(candle.start)
      : Fmt.date(candle.start);
  final values = isLine
      ? strings.crosshairClose(Fmt.number(candle.close))
      : strings.crosshairOhlc(
          Fmt.number(candle.open),
          Fmt.number(candle.high),
          Fmt.number(candle.low),
          Fmt.number(candle.close),
        );
  paintChartLabel(
    canvas,
    style,
    strings.crosshairLine(when, values, Fmt.compact(candle.volume)),
    const Offset(4, 4),
    background,
    style.color!,
  );
}
