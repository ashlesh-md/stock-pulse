import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/sp_picker.dart';
import 'package:stock_pulse/features/chart/di/chart_providers.dart';
import 'package:stock_pulse/features/chart/presentation/chart_labels.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_tool_button.dart';
import 'package:stock_pulse/features/chart/presentation/fullscreen/chart_trade_rail.dart';
import 'package:stock_pulse/features/chart/presentation/studies/studies_sheet.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

class ChartRail extends ConsumerWidget {
  const ChartRail({
    super.key,
    required this.instrumentId,
    required this.onExit,
  });
  final String instrumentId;
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chartControllerProvider(instrumentId)).value;
    final controller = ref.read(chartControllerProvider(instrumentId).notifier);
    final strings = context.strings;
    return SizedBox(
      width: 64,
      child: SingleChildScrollView(
        child: Column(
          children: [
            IconButton(
              tooltip: strings.chart.exit,
              onPressed: onExit,
              icon: const Icon(AppIcons.close),
            ),
            IconButton(
              tooltip: strings.studies.title,
              onPressed: () =>
                  unawaited(showStudiesSheet(context, instrumentId)),
              icon: const Icon(AppIcons.options),
            ),
            DrawingToolButton(instrumentId: instrumentId),
            ChartTradeRail(instrumentId: instrumentId),
            IconButton(
              tooltip: strings.market.intervalTooltip,
              icon: const Icon(AppIcons.time),
              onPressed: state == null
                  ? null
                  : () async {
                      final interval = await showSpPicker(
                        context,
                        title: strings.market.intervalTooltip,
                        values: state.range.intervals,
                        selected: state.interval,
                        label: (v) => v.apiName,
                      );
                      if (interval != null) {
                        await controller.selectInterval(interval);
                      }
                    },
            ),
            IconButton(
              tooltip: strings.market.chartTypeTooltip,
              icon: const Icon(AppIcons.chartCandles),
              onPressed: state == null
                  ? null
                  : () async {
                      final type = await showSpPicker(
                        context,
                        title: strings.market.chartTypeTooltip,
                        values: ChartType.values,
                        selected: state.type,
                        label: (v) => chartTypeLabel(strings.market, v),
                      );
                      if (type != null) {
                        await controller.selectType(type);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
