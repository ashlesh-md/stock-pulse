import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/chart/di/chart_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

/// 1D 1W 1M 3M 6M 1Y 5Y.
class RangeBar extends ConsumerWidget {
  const RangeBar({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      chartControllerProvider(instrumentId)
          .select((s) => s.value?.range ?? ChartRange.d1),
    );
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        runSpacing: 4,
        children: [
          for (final r in ChartRange.values)
            TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: r == selected
                    ? theme.colorScheme.secondaryContainer
                    : null,
                foregroundColor: r == selected
                    ? theme.colorScheme.onSecondaryContainer
                    : theme.hintColor,
              ),
              onPressed: () => ref
                  .read(chartControllerProvider(instrumentId).notifier)
                  .selectRange(r),
              child: Text(r.label),
            ),
        ],
      ),
    );
  }
}
