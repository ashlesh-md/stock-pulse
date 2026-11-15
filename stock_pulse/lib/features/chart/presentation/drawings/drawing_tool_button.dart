import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/sp_picker.dart';
import 'package:stock_pulse/features/chart/di/drawings_providers.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/fib_levels.dart';

class DrawingToolButton extends ConsumerWidget {
  const DrawingToolButton({super.key, required this.instrumentId});
  final String instrumentId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(
      drawingsControllerProvider(instrumentId).select((s) => s.mode),
    );
    final strings = context.strings.chart;
    return IconButton(
      isSelected: mode != null,
      tooltip: strings.draw,
      icon: const Icon(AppIcons.edit),
      onPressed: () async {
        final kind = await showSpPicker<DrawingKind>(
          context,
          title: strings.draw,
          selected: mode,
          values: [
            DrawingKind.horizontal,
            DrawingKind.trendLine,
            if (fibToolReady) DrawingKind.fibRetracement,
          ],
          label: (kind) => switch (kind) {
            DrawingKind.horizontal => strings.horizontal,
            DrawingKind.trendLine => strings.trend,
            DrawingKind.fibRetracement => strings.fibonacci,
          },
        );
        if (kind != null && context.mounted) {
          ref
              .read(drawingsControllerProvider(instrumentId).notifier)
              .start(kind);
        }
      },
    );
  }
}
