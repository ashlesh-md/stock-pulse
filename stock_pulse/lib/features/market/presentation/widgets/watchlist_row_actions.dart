import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/sp_sheet.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';

enum WatchlistRowAction { buy, sell, chart, optionChain, setAlert }

Future<WatchlistRowAction?> showWatchlistRowActions(
  BuildContext context,
  Instrument instrument,
) => showSpSheet<WatchlistRowAction>(
  context,
  maxHeight: MediaQuery.sizeOf(context).height * .75,
  builder: (_) => WatchlistRowActionsSheet(instrument: instrument),
);

/// Context menu for one watchlist instrument. Indexes cannot be traded here.
class WatchlistRowActionsSheet extends StatelessWidget {
  const WatchlistRowActionsSheet({super.key, required this.instrument});

  final Instrument instrument;

  @override
  Widget build(BuildContext context) {
    final market = context.strings.market;
    final orders = context.strings.orders;
    final isIndex = instrument.kind == InstrumentKind.marketIndex;
    final actions = <(WatchlistRowAction, String, IconData)>[
      if (!isIndex) ...[
        (WatchlistRowAction.buy, orders.buy, AppIcons.increase),
        (WatchlistRowAction.sell, orders.sell, AppIcons.decrease),
      ],
      (WatchlistRowAction.chart, market.openChart, AppIcons.watchlist),
      (
        WatchlistRowAction.optionChain,
        market.openOptionChain,
        AppIcons.options,
      ),
      (WatchlistRowAction.setAlert, market.setAlert, AppIcons.notifications),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '${market.rowActionsTitle} · ${instrument.symbol}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final (action, label, icon) in actions)
              ListTile(
                minVerticalPadding: 12,
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.of(context).pop(action),
              ),
          ],
        ),
      ),
    );
  }
}
