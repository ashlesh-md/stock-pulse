import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/chart/di/chart_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/domain/drawing_geometry.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_calculator.dart';
import 'package:stock_pulse/features/chart/presentation/candle_chart.dart';
import 'package:stock_pulse/features/chart/presentation/candle_geometry.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_layer.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_overlay_layer.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

class ChartPlot extends ConsumerWidget {
  const ChartPlot({super.key, required this.instrumentId});
  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (candles, range, interval, type, baseline, previousSession) = ref
        .watch(
          stockDetailControllerProvider(instrumentId).select((state) {
            final detail = state.value!;
            return (
              detail.candles,
              detail.range,
              detail.interval,
              detail.chartType,
              detail.range == ChartRange.d1 ? detail.quote.prevClose : null,
              detail.previousSession,
            );
          }),
        );
    final specs = ref.watch(studiesControllerProvider(instrumentId));
    final series = StudyCalculator().calculate(candles, specs);
    final provider = chartControllerProvider(instrumentId);
    final crosshair = ref.watch(
      provider.select((s) => s.value?.crosshairIndex),
    );
    final (logScale, gridlines) = ref.watch(
      provider.select(
        (s) => (s.value?.logScale ?? false, s.value?.gridlines ?? true),
      ),
    );
    final tickSize = ref.watch(
      stockDetailControllerProvider(instrumentId)
          .select((s) => s.requireValue.instrument.tickSize),
    );
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          if (previousSession)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(context.strings.market.chartPreviousSession),
              ),
            ),
          Expanded(
            child: candles.isEmpty
                ? Center(child: Text(context.strings.market.chartNoCandles))
                : CandleChart(
                    key: ValueKey((range, interval)),
                    candles: candles,
                    interval: interval,
                    type: type,
                    logScale: logScale,
                    gridlines: gridlines,
                    baseline: baseline,
                    crosshairIndex: crosshair,
                    onCrosshairChanged: (index) =>
                        ref.read(provider.notifier).setCrosshair(index),
                    interactionOverlayBuilder: (width, offset) {
                      final plotWidth =
                          constraints.maxWidth - CandleGeometry.axisWidth;
                      final (start, end) = CandleGeometry.visibleRange(
                        candles.length,
                        plotWidth,
                        width,
                        offset,
                      );
                      if (start >= end) return const SizedBox.shrink();
                      final (low, high) = CandleGeometry.priceBounds(
                        candles.sublist(start, end),
                        type,
                        baseline: baseline,
                      );
                      final first = candles[start].start.subtract(
                        Duration(
                          microseconds: (interval.duration.inMicroseconds / 2)
                              .round(),
                        ),
                      );
                      final last = first.add(interval.duration * (end - start));
                      return DrawingLayer(
                        instrumentId: instrumentId,
                        tickSize: tickSize,
                        geometry: DrawingGeometry(
                          first: first,
                          last: last,
                          low: low,
                          high: high,
                          width: (end - start) * width,
                          height:
                              (constraints.maxHeight -
                                  CandleGeometry.timeAxisHeight) *
                              .8,
                        ),
                      );
                    },
                    overlayBuilder: (width, offset) => StudyOverlayLayer(
                      candles: candles,
                      interval: interval,
                      type: type,
                      series: series,
                      candleWidth: width,
                      offset: offset,
                      baseline: baseline,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
