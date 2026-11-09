import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/error_view.dart';
import 'package:stock_pulse/core/widgets/sp_tab_app_bar.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/presentation/widgets/market_breadth.dart';
import 'package:stock_pulse/features/market/presentation/widgets/quote_tile.dart';

/// The watchlist. Reorder handles show only in Edit mode so the rows stay
/// uncluttered; the favourite star is always there.
class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    // Ticks do not rebuild the screen; each QuoteTile watches its own quote.
    final instruments = ref.watch(
      watchlistControllerProvider.select(
        (s) => s.whenData((v) => v.copyWith(quotes: const {})),
      ),
    );
    return Scaffold(
      appBar: SpTabAppBar(
        title: Text(context.strings.market.watchlistTitle),
        actions: [
          if (instruments.hasValue)
            TextButton(
              onPressed: () => setState(() => _editing = !_editing),
              child: Text(
                _editing
                    ? context.strings.common.done
                    : context.strings.market.editWatchlist,
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: MarketBreadth(),
        ),
      ),
      body: switch (instruments) {
        AsyncData(:final value) => _list(value.orderedInstruments),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.read(watchlistControllerProvider.notifier).retry(),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _list(List<Instrument> value) => ReorderableListView.builder(
    buildDefaultDragHandles: false,
    onReorderItem: (oldIndex, newIndex) => ref
        .read(watchlistControllerProvider.notifier)
        .reorder(oldIndex, newIndex),
    itemCount: value.length,
    itemBuilder: (context, i) => QuoteTile(
      key: ValueKey(value[i].symbol),
      instrument: value[i],
      reorderIndex: _editing ? i : null,
      actionsEnabled: !_editing,
      onTap: () => context.pushTo(StockRoute(value[i].id)),
    ),
  );
}
