import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/presentation/widgets/market_depth.dart';

/// The order book of the stock page; rebuilds only when the book changes.
class StockDepth extends ConsumerWidget {
  const StockDepth({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Records compare field by field and the lists are replaced on each
    // update, so a price-only tick does not rebuild this.
    final (bids, asks) = ref.watch(
      stockDetailControllerProvider(instrumentId)
          .select((s) => (s.value!.quote.bids, s.value!.quote.asks)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.strings.market.marketDepth,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          MarketDepth(bids: bids, asks: asks),
        ],
      ),
    );
  }
}
