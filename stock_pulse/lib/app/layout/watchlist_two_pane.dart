import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/app/di/layout_providers.dart';
import 'package:stock_pulse/app/layout/adaptive_two_pane.dart';
import 'package:stock_pulse/app/layout/pane_placeholder.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/market/presentation/screens/stock_detail_screen.dart';
import 'package:stock_pulse/features/market/presentation/screens/watchlist_screen.dart';

/// The watchlist tab: the list beside the picked stock's page on expanded
/// windows, the list alone otherwise (a tap then pushes the stock page).
class WatchlistTwoPane extends ConsumerWidget {
  const WatchlistTwoPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(stockPaneProvider);
    return AdaptiveTwoPane(
      primary: const WatchlistScreen(),
      secondary: id == null
          ? null
          : StockDetailScreen(key: ValueKey(id), instrumentId: id),
      placeholder: PanePlaceholder(
        icon: AppIcons.watchlist,
        message: context.strings.shell.selectStock,
      ),
    );
  }
}
