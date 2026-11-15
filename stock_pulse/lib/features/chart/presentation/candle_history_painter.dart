import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stock_pulse/features/chart/presentation/candle_geometry.dart';
import 'package:stock_pulse/features/chart/presentation/candle_painter.dart';

class CandleHistoryPainter extends CustomPainter {
  CandleHistoryPainter(this.delegate, this.size);
  final CandlePainter delegate;
  final Size size;

  @override
  void paint(Canvas canvas, Size size) => delegate.paint(canvas, size);

  Object get _axis {
    final d = delegate;
    final (start, end) = CandleGeometry.visibleRange(
      d.candles.length,
      size.width - CandleGeometry.axisWidth,
      d.candleWidth,
      d.offset,
    );
    if (start == end) return (0, 0, 0);
    final visible = d.candles.sublist(start, end);
    return (
      CandleGeometry.priceBounds(visible, d.type, baseline: d.baseline),
      (visible.length > 1 ? visible.take(visible.length - 1) : visible)
          .map((c) => c.volume)
          .reduce(max),
      CandleGeometry.isLine(d.type)
          ? d.colors.directionOf(
              d.candles.last.close - (d.baseline ?? visible.first.open),
            )
          : null,
    );
  }

  @override
  bool shouldRepaint(CandleHistoryPainter old) {
    final a = delegate;
    final b = old.delegate;
    return size != old.size ||
        _axis != old._axis ||
        a.type != b.type ||
        a.interval != b.interval ||
        a.candleWidth != b.candleWidth ||
        a.offset != b.offset ||
        a.colors != b.colors ||
        a.showVolume != b.showVolume ||
        !listEquals(
          a.candles.take(max(0, a.candles.length - 1)).toList(),
          b.candles.take(max(0, b.candles.length - 1)).toList(),
        );
  }
}
