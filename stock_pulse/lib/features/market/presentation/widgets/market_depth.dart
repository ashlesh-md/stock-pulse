import 'package:flutter/material.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

/// The 5-level order book ("market depth").
///
/// Left: bids = buyers waiting, highest price first. Right: asks = sellers
/// waiting, lowest price first. The gap between the best bid and best ask is
/// the spread. Bars show each level's quantity relative to the largest.
class MarketDepth extends StatelessWidget {
  const MarketDepth({super.key, required this.bids, required this.asks});

  final List<DepthLevel> bids;
  final List<DepthLevel> asks;

  @override
  Widget build(BuildContext context) {
    if (bids.isEmpty && asks.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final strings = context.strings.market;
    final maxQty = [
      ...bids,
      ...asks,
    ].map((l) => l.quantity).fold(1, (a, b) => a > b ? a : b);
    final totalBid = bids.fold(0, (s, l) => s + l.quantity);
    final totalAsk = asks.fold(0, (s, l) => s + l.quantity);
    final header = theme.textTheme.labelSmall?.copyWith(color: theme.hintColor);

    Widget side(List<DepthLevel> levels, Color color, {required bool isBid}) =>
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isBid ? strings.depthBid : strings.depthAsk,
                      style: header,
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      strings.depthOrders,
                      textAlign: TextAlign.right,
                      style: header,
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      strings.depthQuantity,
                      textAlign: TextAlign.right,
                      style: header,
                    ),
                  ),
                ],
              ),
              for (final l in levels)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 1),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: isBid
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      end: isBid ? Alignment.centerLeft : Alignment.centerRight,
                      stops: [l.quantity / maxQty, l.quantity / maxQty],
                      colors: [
                        color.withValues(alpha: 0.14),
                        color.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          Fmt.number(l.price),
                          style: TextStyle(
                            color: color,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: Text(
                          l.orders.toString(),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          l.quantity.toString(),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 8),
              Row(
                children: [
                  Expanded(child: Text(strings.depthTotal, style: header)),
                  Text(Fmt.compact(isBid ? totalBid : totalAsk)),
                ],
              ),
            ],
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        side(bids, context.sp.up, isBid: true),
        const SizedBox(width: 12),
        side(asks, context.sp.down, isBid: false),
      ],
    );
  }
}
