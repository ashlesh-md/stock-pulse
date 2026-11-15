import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/strings/market_strings.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/features/chart/presentation/candle_crosshair_paint.dart';
import 'package:stock_pulse/features/chart/presentation/candle_geometry.dart';
import 'package:stock_pulse/features/chart/presentation/chart_paint_text.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

/// Draws the price chart. Pure paint: every input is a field, so
/// [shouldRepaint] can compare them.
class CandlePainter extends CustomPainter {
  CandlePainter({
    required this.candles,
    required this.type,
    required this.interval,
    required this.baseline,
    required this.candleWidth,
    required this.offset,
    required this.crosshair,
    required this.gridColor,
    required this.textStyle,
    required this.labelBackground,
    required this.colors,
    required this.strings,
    this.showVolume = true,
    this.logScale = false,
    this.gridlines = true,
    this.historyOnly = false,
    this.liveOnly = false,
    this.onPainted,
  });

  final List<Candle> candles;
  final ChartType type;
  final CandleInterval interval;
  final double? baseline;
  final double candleWidth;
  final int offset;
  final int? crosshair;
  final Color gridColor;
  final TextStyle textStyle;
  final Color labelBackground;

  /// Up/down tokens for candle direction.
  final SpColors colors;
  final MarketStrings strings;
  final bool showVolume;
  final bool logScale;
  final bool gridlines;
  final bool historyOnly;
  final bool liveOnly;
  final VoidCallback? onPainted;

  @override
  void paint(Canvas canvas, Size size) {
    onPainted?.call();
    if (candles.isEmpty) return;
    final plotWidth = size.width - CandleGeometry.axisWidth;
    final (start, end) = CandleGeometry.visibleRange(
      candles.length,
      plotWidth,
      candleWidth,
      offset,
    );
    if (end <= start) return;
    final visible = candles.sublist(start, end);
    final isLine = CandleGeometry.isLine(type);

    final chartBottom = size.height - CandleGeometry.timeAxisHeight;
    final priceHeight = showVolume ? chartBottom * 0.8 : chartBottom;
    final volumeTop = priceHeight + 8;

    final (rawLo, rawHi) = CandleGeometry.priceBounds(
      visible,
      type,
      baseline: baseline,
    );
    final useLog = logScale && rawLo > 0 && rawHi > rawLo;
    double y(double price) => CandleGeometry.priceY(
      price,
      rawLo,
      rawHi,
      priceHeight,
      logarithmic: useLog,
    );

    double x(int i) => (i + 0.5) * candleWidth; // centre of slot i
    final volumeCandles = historyOnly && visible.length > 1
        ? visible.take(visible.length - 1)
        : visible;
    final maxVolume = volumeCandles.map((c) => c.volume).reduce(max).toDouble();

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (var i = 0; gridlines && !historyOnly && i <= 4; i++) {
      final scaled = rawLo + (rawHi - rawLo) * i / 4;
      final price = useLog
          ? exp(log(rawLo) + (log(rawHi) - log(rawLo)) * i / 4)
          : scaled;
      final gy = y(price);
      canvas.drawLine(Offset(0, gy), Offset(plotWidth, gy), grid);
      paintChartText(
        canvas,
        textStyle,
        Fmt.number(price),
        Offset(plotWidth + 4, gy - 6),
      );
    }

    final first = liveOnly ? visible.length - 1 : 0;
    final last = historyOnly ? visible.length - 1 : visible.length;
    final gap = candleWidth >= 4 ? candleWidth * 0.2 : 0.0;
    final bar = Paint();
    for (var i = first; showVolume && i < last; i++) {
      final c = visible[i];
      final vh = maxVolume == 0
          ? 0.0
          : c.volume / maxVolume * (chartBottom - volumeTop);
      bar.color = colors.directionOf(c.close - c.open).withValues(alpha: 0.3);
      canvas.drawRect(
        Rect.fromLTRB(
          i * candleWidth + gap / 2,
          chartBottom - vh,
          (i + 1) * candleWidth - gap / 2,
          chartBottom,
        ),
        bar,
      );
    }

    // Line/area colour: above or below where the range started.
    final reference = baseline ?? visible.first.open;
    final trendColor = colors.directionOf(candles.last.close - reference);

    switch (type) {
      case ChartType.line || ChartType.area:
        final from = max(0, first - 1);
        final path = Path()..moveTo(x(from), y(visible[from].close));
        for (var i = from + 1; i < last; i++) {
          path.lineTo(x(i), y(visible[i].close));
        }
        if (type == ChartType.area) {
          final fill = Path.from(path)
            ..lineTo(x(max(0, last - 1)), priceHeight)
            ..lineTo(x(from), priceHeight)
            ..close();
          canvas.drawPath(
            fill,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  trendColor.withValues(alpha: 0.35),
                  trendColor.withValues(alpha: 0.0),
                ],
              ).createShader(Rect.fromLTWH(0, 0, plotWidth, priceHeight)),
          );
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = trendColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeJoin = StrokeJoin.round,
        );
      case ChartType.ohlc:
        // Vertical high–low line, open tick on the left, close tick on the right.
        final stroke = Paint()..strokeWidth = max(1.0, candleWidth * 0.12);
        final tick = max(1.0, candleWidth * 0.35);
        for (var i = first; i < last; i++) {
          final c = visible[i];
          stroke.color = colors.directionOf(c.close - c.open);
          final mid = x(i);
          canvas
            ..drawLine(Offset(mid, y(c.high)), Offset(mid, y(c.low)), stroke)
            ..drawLine(
              Offset(mid - tick, y(c.open)),
              Offset(mid, y(c.open)),
              stroke,
            )
            ..drawLine(
              Offset(mid, y(c.close)),
              Offset(mid + tick, y(c.close)),
              stroke,
            );
        }
      case ChartType.candles || ChartType.heikinAshi:
        final body = Paint();
        final wick = Paint()..strokeWidth = 1;
        for (var i = first; i < last; i++) {
          final c = visible[i];
          final color = colors.directionOf(c.close - c.open);
          body.color = color;
          wick.color = color;
          final left = i * candleWidth + gap / 2;
          final right = max(left + 1, (i + 1) * candleWidth - gap / 2);
          final mid = (left + right) / 2;
          canvas.drawLine(Offset(mid, y(c.high)), Offset(mid, y(c.low)), wick);
          final top = y(max(c.open, c.close));
          final bottom = max(
            y(min(c.open, c.close)),
            top + 1,
          ); // doji: 1px line
          canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), body);
        }
    }

    if (historyOnly) return;

    // Baseline (1D: previous close), dotted.
    if (baseline != null) {
      final by = y(baseline!);
      final dots = Paint()
        ..color = textStyle.color!.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      for (var dx = 0.0; dx < plotWidth; dx += 4) {
        canvas.drawLine(
          Offset(dx, by),
          Offset(min(dx + 1.5, plotWidth), by),
          dots,
        );
      }
    }

    // Time labels roughly every 90 px, formatted for the interval and span.
    final span = visible.last.start.difference(visible.first.start);
    final every = max(1, (90 / candleWidth).round());
    for (var i = 0; i < visible.length; i += every) {
      paintChartText(
        canvas,
        textStyle,
        CandleGeometry.axisLabel(visible[i].start, span, interval),
        Offset(i * candleWidth, chartBottom + 2),
      );
    }

    // Last price line and label.
    final lastPrice = candles.last.close;
    final ly = y(lastPrice).clamp(0.0, priceHeight);
    final dash = Paint()
      ..color = trendColor
      ..strokeWidth = 1;
    for (var dx = 0.0; dx < plotWidth; dx += 6) {
      canvas.drawLine(Offset(dx, ly), Offset(min(dx + 3, plotWidth), ly), dash);
    }
    paintChartLabel(
      canvas,
      textStyle,
      Fmt.number(lastPrice),
      Offset(plotWidth + 2, ly - 8),
      trendColor,
      colors.surface0,
    );

    final index = crosshair;
    if (index != null && index >= start && index < end) {
      paintCandleCrosshair(
        canvas,
        candle: candles[index],
        x: x(index - start),
        bottom: chartBottom,
        interval: interval,
        isLine: isLine,
        style: textStyle,
        background: labelBackground,
        strings: strings,
      );
    }
  }

  /// Repaint only when something drawn changed. `candles` is a new list
  /// after every live update (immutable state), so identity is enough.
  @override
  bool shouldRepaint(CandlePainter old) =>
      !identical(old.candles, candles) ||
      old.type != type ||
      old.baseline != baseline ||
      old.candleWidth != candleWidth ||
      old.offset != offset ||
      old.showVolume != showVolume ||
      old.logScale != logScale ||
      old.gridlines != gridlines ||
      old.crosshair != crosshair ||
      old.gridColor != gridColor ||
      old.colors != colors ||
      old.strings != strings;
}
