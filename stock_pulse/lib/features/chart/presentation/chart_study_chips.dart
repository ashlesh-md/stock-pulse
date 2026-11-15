import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_calculator.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_chip_row.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';

class ChartStudyChips extends ConsumerWidget {
  const ChartStudyChips({super.key, required this.instrumentId});
  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (candles, interval) = ref.watch(
      stockDetailControllerProvider(instrumentId).select((state) {
        final detail = state.value!;
        return (detail.candles, detail.interval);
      }),
    );
    final specs = ref.watch(studiesControllerProvider(instrumentId));
    return StudyChipRow(
      instrumentId: instrumentId,
      interval: interval,
      series: StudyCalculator().calculate(candles, specs),
    );
  }
}
