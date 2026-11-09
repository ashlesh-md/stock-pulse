import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_calculator.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_chip_row.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_overlay_layer.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_pane_stack.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/presentation/widgets/candle_chart.dart';

/// The stock page's chart: rebuilds only on candle, range or type changes.
class StockChart extends ConsumerStatefulWidget {
  const StockChart({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  ConsumerState<StockChart> createState() => _StockChartState();
}

class _StockChartState extends ConsumerState<StockChart> {
  final _calculator = StudyCalculator();
  @override
  Widget build(BuildContext context) {
    final instrumentId = widget.instrumentId;
    final (candles, range, interval, type, base) = ref.watch(
      stockDetailControllerProvider(instrumentId).select((s) {
        final v = s.value!;
        return (
          v.candles,
          v.range,
          v.interval,
          v.chartType,
          v.range == ChartRange.d1 ? v.quote.prevClose : null,
        );
      }),
    );
    final specs = ref.watch(studiesControllerProvider(instrumentId));
    final chartInterval = interval;
    final calculatedStudySeries = _calculator.calculate(candles, specs);
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxHeight;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
          child: Column(
            children: [
              StudyChipRow(
                instrumentId: instrumentId,
                interval: chartInterval,
                series: calculatedStudySeries,
              ),
              Expanded(
                child: CandleChart(
                  // A new range or interval resets zoom and pan to "fit".
                  key: ValueKey((range, interval)),
                  candles: candles,
                  interval: interval,
                  type: type,
                  baseline: base,
                  overlayBuilder: (width, offset) => StudyOverlayLayer(
                    candles: candles,
                    interval: interval,
                    type: type,
                    series: calculatedStudySeries,
                    candleWidth: width,
                    offset: offset,
                    baseline: base,
                  ),
                ),
              ),
              StudyPaneStack(
                series: calculatedStudySeries,
                maxPaneHeight: chartHeight * 0.4,
              ),
            ],
          ),
        );
      },
    );
  }
}
