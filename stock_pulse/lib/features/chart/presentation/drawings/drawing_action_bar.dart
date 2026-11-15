import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/chart/di/drawings_providers.dart';

class DrawingActionBar extends ConsumerWidget {
  const DrawingActionBar({super.key, required this.instrumentId});
  final String instrumentId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(drawingsControllerProvider(instrumentId));
    final controller = ref.read(
      drawingsControllerProvider(instrumentId).notifier,
    );
    final strings = context.strings.chart;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (state.atLimit) Text(strings.limit),
        if (state.mode != null)
          TextButton.icon(
            onPressed: () => controller.start(null),
            icon: const Icon(AppIcons.close),
            label: Text(strings.cancel),
          ),
        if (state.selectedId != null)
          TextButton.icon(
            onPressed: controller.deleteSelected,
            icon: const Icon(AppIcons.delete),
            label: Text(strings.delete),
          ),
      ],
    );
  }
}
