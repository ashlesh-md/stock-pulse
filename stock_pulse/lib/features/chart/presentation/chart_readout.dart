import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/chart/di/chart_providers.dart';
import 'package:stock_pulse/features/chart/presentation/chart_stale_badge.dart';
import 'package:stock_pulse/features/chart/presentation/readout_row.dart';

class ChartReadout extends ConsumerWidget {
  const ChartReadout({super.key, required this.instrumentId});
  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (candle, previousClose) = ref.watch(
      chartReadoutProvider(instrumentId),
    );
    return ReadoutRow(
      candle: candle,
      previousClose: previousClose,
      staleBadge: ChartStaleBadge(instrumentId: instrumentId),
    );
  }
}
