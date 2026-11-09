import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/change_chip.dart';
import 'package:stock_pulse/core/widgets/market_status_pill.dart';
import 'package:stock_pulse/core/widgets/sp_price_cell.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';

/// Name line, live price, change and last trade time.
class StockHeader extends ConsumerWidget {
  const StockHeader({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = stockDetailControllerProvider(instrumentId);
    final q = ref.watch(provider.select((s) => s.value!.quote));
    final instrument = ref.watch(provider.select((s) => s.value!.instrument));
    final theme = Theme.of(context);
    final strings = context.strings.market;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.instrumentLine(
                    instrument.name,
                    instrument.exchange,
                    instrument.sector,
                  ),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const MarketStatusPill(),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: SpPriceCell(
                  value: q.ltp,
                  text: Fmt.price(q.ltp),
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.left,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ChangeChip(
                    change: q.change,
                    changePct: q.changePercent,
                    compact: false,
                  ),
                ),
              ),
            ],
          ),
          Text(
            strings.lastTrade(Fmt.time(q.lastTradeTime)),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
