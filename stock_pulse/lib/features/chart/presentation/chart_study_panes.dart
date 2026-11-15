import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_calculator.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_pane_stack.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';

class ChartStudyPanes extends ConsumerWidget {
  const ChartStudyPanes({
    super.key,
    required this.instrumentId,
    required this.maxHeight,
  });
  final String instrumentId;
  final double maxHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candles = ref.watch(
      stockDetailControllerProvider(instrumentId)
          .select((state) => state.value!.candles),
    );
    final specs = ref.watch(studiesControllerProvider(instrumentId));
    return StudyPaneStack(
      series: StudyCalculator().calculate(candles, specs),
      maxPaneHeight: maxHeight,
    );
  }
}
