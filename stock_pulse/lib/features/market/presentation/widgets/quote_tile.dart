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
    final controls = Row(
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
    );
    final title = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          instrument.symbol,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          strings.market.instrumentSubtitle(
            instrument.exchange,
            instrument.name,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    final price = quote == null
        ? Text(strings.common.noValue)
        : SpPriceCell(
            value: quote.ltp,
            text: Fmt.number(quote.ltp),
            isStale: stale,
          );
    final change = quote == null
        ? const SizedBox.shrink()
        : ChangeChip(change: quote.change, changePct: quote.changePercent);
    return InkWell(
      onTap: onTap,
      onLongPress: actionsEnabled ? () => _showActions(context, ref) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 420 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            if (stacked) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      controls,
                      const SizedBox(width: 8),
                      Expanded(child: title),
                      const SizedBox(width: 8),
                      // At large text the controls and the price can be
                      // wider than a phone; past half the row the price
                      // shrinks rather than being cut off.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth / 2,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: price,
                        ),
                      ),
                    ],
                  ),
                  Align(alignment: Alignment.centerRight, child: change),
                ],
              );
            }
            return Row(
              children: [
                controls,
                const SizedBox(width: 8),
                Expanded(child: title),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [price, change],
                ),
              ],
            );
          },
        ),
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
