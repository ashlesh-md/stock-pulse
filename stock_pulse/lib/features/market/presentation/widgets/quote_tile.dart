import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/freshness.dart';
import 'package:stock_pulse/core/widgets/change_chip.dart';
import 'package:stock_pulse/core/widgets/sp_price_cell.dart';
import 'package:stock_pulse/features/market/application/live_quote_provider.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/presentation/widgets/watchlist_row_actions.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';

typedef _QuoteFreshnessKey = ({String id, DateTime asOf, bool fromCache});

final _quoteStaleProvider = Provider.autoDispose
    .family<bool, _QuoteFreshnessKey>((ref, key) {
      final now =
          ref.watch(freshnessTickProvider).value ??
          ref.read(serverClockProvider).now();
      final latest = ref.read(latestQuoteSnapshotProvider(key.id));
      final liveConfirmation = latest != null && latest.asOf.isAfter(key.asOf)
          ? latest
          : null;
      return (liveConfirmation?.fromCache ?? key.fromCache) ||
          now.difference(liveConfirmation?.asOf ?? key.asOf) > kStaleAfter;
    });

/// One watchlist row.
///
/// It watches ONLY its own quote with `select`. When a tick batch updates
/// three of twelve stocks, the controller emits a new state, but only these
/// three rows rebuild: `select` compares the old and new Quote with `==` and
/// skips the rest.
class QuoteTile extends ConsumerWidget {
  const QuoteTile({
    super.key,
    required this.instrument,
    required this.onTap,
    this.reorderIndex,
    this.actionsEnabled = true,
  });

  final Instrument instrument;
  final VoidCallback onTap;
  final int? reorderIndex;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(
      watchlistControllerProvider.select(
        (s) => s.value?.quotes[instrument.symbol],
      ),
    );
    final strings = context.strings;
    final stale =
        quote != null &&
        ref.watch(
          _quoteStaleProvider((
            id: instrument.id,
            asOf: quote.asOf,
            fromCache: quote.fromCache,
          )),
        );
    final favourite = ref.watch(
      watchlistControllerProvider.select(
        (s) => s.value?.favouriteIds.contains(instrument.id) ?? false,
      ),
    );
    return ListTile(
      onTap: onTap,
      onLongPress: actionsEnabled ? () => _showActions(context, ref) : null,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reorderIndex case final int index)
            ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: strings.market.reorder,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(AppIcons.reorder),
                ),
              ),
            ),
          IconButton(
            tooltip: favourite
                ? strings.market.unpinFavourite
                : strings.market.pinFavourite,
            onPressed: () => ref
                .read(watchlistControllerProvider.notifier)
                .toggleFavourite(instrument.id),
            icon: Icon(
              favourite ? AppIcons.favourite : AppIcons.favouriteOutline,
            ),
          ),
        ],
      ),
      title: Text(
        instrument.symbol,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        strings.market.instrumentSubtitle(instrument.exchange, instrument.name),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: quote == null
          ? Text(strings.common.noValue)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SpPriceCell(
                  value: quote.ltp,
                  text: Fmt.number(quote.ltp),
                  isStale: stale,
                ),
                ChangeChip(
                  change: quote.change,
                  changePct: quote.changePercent,
                ),
              ],
            ),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final action = await showWatchlistRowActions(context, instrument);
    if (action == null || !context.mounted) return;
    ref
        .read(analyticsProvider)
        .log(
          Events.watchlistRowAction(
            action: action.name,
            instrumentKind: instrument.kind.name,
          ),
        );
    switch (action) {
      case WatchlistRowAction.buy:
      case WatchlistRowAction.sell:
        await context.pushTo<void>(
          OrderTicketRoute(
            OrderTicketArgs(
              instrumentId: instrument.id,
              side: action == WatchlistRowAction.buy
                  ? OrderSide.buy
                  : OrderSide.sell,
            ),
          ),
        );
      case WatchlistRowAction.chart:
        await context.pushTo<void>(StockRoute(instrument.id));
      case WatchlistRowAction.optionChain:
        context.goTo(OptionChainRoute(underlying: instrument.id));
      case WatchlistRowAction.setAlert:
        await context.pushTo<void>(const AlertsRoute());
    }
  }
}
