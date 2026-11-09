import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/strings/market_strings.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/presentation/widgets/candle_geometry.dart';

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

  @override
  void paint(Canvas canvas, Size size) {
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

    final (lo, hi) = CandleGeometry.priceBounds(
      visible,
      type,
      baseline: baseline,
    );
    double y(double price) => (hi - price) / (hi - lo) * priceHeight;
    double x(int i) => (i + 0.5) * candleWidth; // centre of slot i
    final maxVolume = visible.map((c) => c.volume).reduce(max).toDouble();

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;
    for (var i = 0; i <= 4; i++) {
      final price = lo + (hi - lo) * i / 4;
      final gy = y(price);
      canvas.drawLine(Offset(0, gy), Offset(plotWidth, gy), grid);
      _text(canvas, Fmt.number(price), Offset(plotWidth + 4, gy - 6));
    }

    final gap = candleWidth >= 4 ? candleWidth * 0.2 : 0.0;
    final bar = Paint();
    for (var i = 0; showVolume && i < visible.length; i++) {
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
        final path = Path()..moveTo(x(0), y(visible.first.close));
        for (var i = 1; i < visible.length; i++) {
          path.lineTo(x(i), y(visible[i].close));
        }
        if (type == ChartType.area) {
          final fill = Path.from(path)
            ..lineTo(x(visible.length - 1), priceHeight)
            ..lineTo(x(0), priceHeight)
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
        for (var i = 0; i < visible.length; i++) {
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
        for (var i = 0; i < visible.length; i++) {
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
      _text(
        canvas,
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
    _label(
      canvas,
      Fmt.number(lastPrice),
      Offset(plotWidth + 2, ly - 8),
      trendColor,
      colors.surface0,
    );

    // Crosshair.
    final index = crosshair;
    if (index != null && index >= start && index < end) {
      final c = candles[index];
      final cx = x(index - start);
      final line = Paint()
        ..color = textStyle.color!.withValues(alpha: 0.6)
        ..strokeWidth = 0.7;
      canvas.drawLine(Offset(cx, 0), Offset(cx, chartBottom), line);
      final when = interval.isIntraday
          ? Fmt.dayTime(c.start)
          : Fmt.date(c.start);
      final values = isLine
          ? strings.crosshairClose(Fmt.number(c.close))
          : strings.crosshairOhlc(
              Fmt.number(c.open),
              Fmt.number(c.high),
              Fmt.number(c.low),
              Fmt.number(c.close),
            );
      _label(
        canvas,
        strings.crosshairLine(when, values, Fmt.compact(c.volume)),
        const Offset(4, 4),
        labelBackground,
        textStyle.color!,
      );
    }
  }

  void _text(Canvas canvas, String text, Offset at) {
    (TextPainter(
      text: TextSpan(text: text, style: textStyle),
      textDirection: TextDirection.ltr,
    )..layout()).paint(canvas, at);
  }

  void _label(
    Canvas canvas,
    String text,
    Offset at,
    Color background,
    Color foreground,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(color: foreground),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(at.dx, at.dy, tp.width + 8, tp.height + 4),
        const Radius.circular(3),
      ),
      Paint()..color = background,
    );
    tp.paint(canvas, at + const Offset(4, 2));
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
      old.crosshair != crosshair ||
      old.gridColor != gridColor ||
      old.colors != colors ||
      old.strings != strings;
}
