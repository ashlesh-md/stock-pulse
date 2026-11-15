import 'package:flutter/material.dart';
import 'package:stock_pulse/features/chart/presentation/chart_plot.dart';
import 'package:stock_pulse/features/chart/presentation/chart_readout.dart';
import 'package:stock_pulse/features/chart/presentation/chart_study_chips.dart';
import 'package:stock_pulse/features/chart/presentation/chart_study_panes.dart';
import 'package:stock_pulse/features/chart/presentation/crosshair_layer.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_action_bar.dart';

/// The stock page's chart. Each live surface subscribes only to its own data:
/// candle ticks redraw the plot without rebuilding a historical readout.
class ChartView extends StatelessWidget {
  const ChartView({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 0),
      child: Column(
        children: [
          ChartStudyChips(instrumentId: instrumentId),
          DrawingActionBar(instrumentId: instrumentId),
          ChartReadout(instrumentId: instrumentId),
          ChartPriceActions(instrumentId: instrumentId),
          Expanded(child: ChartPlot(instrumentId: instrumentId)),
          ChartStudyPanes(
            instrumentId: instrumentId,
            maxHeight: constraints.maxHeight * 0.4,
          ),
        ],
      ),
    ),
  );
}

/// Compatibility name for existing stock-page integrations.
typedef StockChart = ChartView;
