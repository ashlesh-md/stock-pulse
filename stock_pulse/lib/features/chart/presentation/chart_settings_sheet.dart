import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/sp_sheet.dart';
import 'package:stock_pulse/features/chart/di/chart_providers.dart';

Future<void> showChartSettingsSheet(
  BuildContext context,
  String instrumentId,
) => showSpSheet<void>(
  context,
  builder: (_) => _ChartSettings(instrumentId: instrumentId),
);

class _ChartSettings extends ConsumerWidget {
  const _ChartSettings({required this.instrumentId});
  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.chart;
    final provider = chartControllerProvider(instrumentId);
    final state = ref.watch(provider).value;
    final controller = ref.read(provider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                strings.settings,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              secondary: const Icon(AppIcons.chartCandles),
              title: Text(strings.logScale),
              value: state?.logScale ?? false,
              onChanged: state == null
                  ? null
                  : (enabled) => controller.setLogScale(enabled: enabled),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile.adaptive(
              secondary: const Icon(AppIcons.options),
              title: Text(strings.gridlines),
              value: state?.gridlines ?? true,
              onChanged: state == null
                  ? null
                  : (enabled) => controller.setGridlines(enabled: enabled),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
