import 'package:flutter/material.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_series.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_painter.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/presentation/widgets/candle_geometry.dart';

class StudyOverlayLayer extends StatelessWidget {
  const StudyOverlayLayer({
    super.key,
    required this.candles,
    required this.interval,
    required this.type,
    required this.series,
    required this.candleWidth,
    required this.offset,
    this.baseline,
  });
  final List<Candle> candles;
  final CandleInterval interval;
  final ChartType type;
  final Map<StudySpec, StudySeries> series;
  final double candleWidth;
  final int offset;
  final double? baseline;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final (start, end) = CandleGeometry.visibleRange(
        candles.length,
        size.maxWidth - CandleGeometry.axisWidth,
        candleWidth,
        offset,
      );
      if (end <= start) return const SizedBox.shrink();
      final (low, high) = CandleGeometry.priceBounds(
        candles.sublist(start, end),
        type,
        baseline: baseline,
      );
      final lines = [
        for (final entry in series.entries)
          if (entry.key.kind != StudyKind.rsi &&
              entry.key.kind != StudyKind.macd &&
              (entry.key.kind != StudyKind.vwap || interval.isIntraday))
            ...entry.value.lines.values,
      ];
      final sp = context.sp;
      return CustomPaint(
        size: Size.infinite,
        painter: StudyPainter(
          lines: lines,
          start: start,
          end: end,
          width: candleWidth,
          low: low,
          high: high,
          colors: [sp.accent, sp.warn, sp.info, sp.textSecondary],
          priceOverlay: true,
        ),
      );
    },
  );
}
