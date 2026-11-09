import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';

/// `▲ 7 advancing  ▼ 5 declining` under the watchlist title.
class MarketBreadth extends ConsumerWidget {
  const MarketBreadth({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (up, down) = ref.watch(
      watchlistControllerProvider.select(
        (s) => (s.value?.advancing ?? 0, s.value?.declining ?? 0),
      ),
    );
    final style = Theme.of(context).textTheme.labelMedium;
    final strings = context.strings.market;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            strings.advancing(up),
            style: style?.copyWith(color: context.sp.up),
          ),
          const SizedBox(width: 16),
          Text(
            strings.declining(down),
            style: style?.copyWith(color: context.sp.down),
          ),
        ],
      ),
    );
  }
}
