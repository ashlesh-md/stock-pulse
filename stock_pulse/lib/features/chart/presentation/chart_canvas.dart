import 'package:flutter/material.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/features/chart/presentation/candle_history_painter.dart';
import 'package:stock_pulse/features/chart/presentation/candle_painter.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

class ChartCanvas extends StatelessWidget {
  const ChartCanvas({
    super.key,
    required this.candles,
    required this.interval,
    required this.type,
    required this.candleWidth,
    required this.offset,
    required this.crosshair,
    required this.size,
    this.baseline,
    this.showVolume = true,
    this.logScale = false,
    this.gridlines = true,
    this.overlayBuilder,
    this.interactionOverlayBuilder,
    this.onPainterPainted,
  });
  final List<Candle> candles;
  final CandleInterval interval;
  final ChartType type;
  final double candleWidth;
  final int offset;
  final int? crosshair;
  final Size size;
  final double? baseline;
  final bool showVolume;
  final bool logScale;
  final bool gridlines;
  final Widget Function(double, int)? overlayBuilder;
  final Widget Function(double, int)? interactionOverlayBuilder;
  final ValueChanged<String>? onPainterPainted;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            size: Size(size.width, size.height),
            painter: CandleHistoryPainter(
              CandlePainter(
                candles: candles,
                type: type,
                interval: interval,
                baseline: baseline,
                candleWidth: candleWidth,
                offset: offset,
                crosshair: crosshair,
                gridColor: theme.dividerColor.withValues(alpha: 0.4),
                textStyle: theme.textTheme.labelSmall!.copyWith(
                  color: theme.hintColor,
                ),
                labelBackground: theme.colorScheme.surfaceContainerHighest,
                colors: context.sp,
                strings: context.strings.market,
                showVolume: showVolume,
                logScale: logScale,
                gridlines: gridlines,
                historyOnly: true,
                onPainted: () => onPainterPainted?.call('history'),
              ),
              Size(size.width, size.height),
            ),
          ),
        ),
        CustomPaint(
          size: Size(size.width, size.height),
          painter: CandlePainter(
            candles: candles,
            type: type,
            interval: interval,
            baseline: baseline,
            candleWidth: candleWidth,
            offset: offset,
            crosshair: crosshair,
            gridColor: theme.dividerColor.withValues(alpha: 0.4),
            textStyle: theme.textTheme.labelSmall!.copyWith(
              color: theme.hintColor,
            ),
            labelBackground: theme.colorScheme.surfaceContainerHighest,
            colors: context.sp,
            strings: context.strings.market,
            showVolume: showVolume,
            logScale: logScale,
            gridlines: gridlines,
            liveOnly: true,
            onPainted: () => onPainterPainted?.call('live'),
          ),
        ),
        if (interactionOverlayBuilder != null)
          interactionOverlayBuilder!(candleWidth, offset),
        if (overlayBuilder != null)
          IgnorePointer(child: overlayBuilder!(candleWidth, offset)),
      ],
    );
  }
}
