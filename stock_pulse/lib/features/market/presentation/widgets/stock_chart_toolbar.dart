import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/widgets/sp_picker.dart';
import 'package:stock_pulse/features/chart/presentation/studies/studies_sheet.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/presentation/widgets/chart_labels.dart';

/// Range performance and high/low, plus the interval and chart-type menus.
class StockChartToolbar extends ConsumerWidget {
  const StockChartToolbar({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = stockDetailControllerProvider(instrumentId);
    final s = ref.watch(provider.select((s) => s.value!));
    final controller = ref.read(provider.notifier);
    final theme = Theme.of(context);
    final strings = context.strings.market;
    final change = s.rangeChange;
    final percent = s.rangeChangePercent;

    final summary = SizedBox(
      height: 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 20,
            child: change == null || percent == null
                ? null
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      strings.rangePerformance(
                        s.range.label,
                        Fmt.percent(percent),
                        Fmt.signed(change),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: context.sp.directionOf(change),
                      ),
                    ),
                  ),
          ),
          SizedBox(
            height: 20,
            child: s.rangeHigh == null
                ? null
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      strings.rangeHighLow(
                        Fmt.number(s.rangeHigh!),
                        Fmt.number(s.rangeLow!),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
    final intervalPicker = SpPicker<CandleInterval>(
      title: strings.intervalTooltip,
      values: s.range.intervals,
      label: (interval) => intervalOptionLabel(strings, interval),
      selected: s.interval,
      selectedLabel: (interval) => interval.apiName,
      onChanged: controller.selectInterval,
    );
    final chartTypePicker = SpPicker<ChartType>(
      title: strings.chartTypeTooltip,
      values: ChartType.values,
      label: (type) => chartTypeLabel(strings, type),
      selected: s.chartType,
      onChanged: controller.selectChartType,
    );
    final loadStatus = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (s.loadingCandles)
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        if (s.candlesFailed)
          Tooltip(
            message: strings.chartLoadFailed,
            child: Icon(AppIcons.error, color: context.sp.warn),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 480;
        final studiesButton = IconButton(
          tooltip: context.strings.studies.title,
          onPressed: () => unawaited(showStudiesSheet(context, instrumentId)),
          icon: const Icon(AppIcons.options),
        );
        if (narrow) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    studiesButton,
                    Expanded(child: summary),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      loadStatus,
                      SizedBox(width: 128, child: intervalPicker),
                      SizedBox(width: 144, child: chartTypePicker),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
          child: Row(
            children: [
              studiesButton,
              Expanded(child: summary),
              loadStatus,
              intervalPicker,
              chartTypePicker,
            ],
          ),
        );
      },
    );
  }
}
