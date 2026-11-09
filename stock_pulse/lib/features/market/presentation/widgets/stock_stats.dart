import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';

/// Open, high, low, volume, bid/ask and spread in a three-column grid.
class StockStats extends ConsumerWidget {
  const StockStats({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(
      stockDetailControllerProvider(instrumentId).select((s) => s.value!.quote),
    );
    final strings = context.strings;
    final none = strings.common.noValue;
    String p(double? v) => v == null ? none : Fmt.number(v);
    final m = strings.market;
    final items = <(String, String)>[
      (m.statOpen, p(q.open)),
      (m.statHigh, p(q.high)),
      (m.statLow, p(q.low)),
      (m.statPrevClose, p(q.prevClose)),
      (m.statVolume, q.volume == null ? none : Fmt.compact(q.volume!)),
      (m.statLastQty, q.lastQuantity?.toString() ?? none),
      (m.statBid, p(q.bid)),
      (m.statAsk, p(q.ask)),
      (m.statSpread, p(q.spread)),
    ];
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        runSpacing: 12,
        children: [
          for (final (label, value) in items)
            SizedBox(
              width: (MediaQuery.sizeOf(context).width - 32) / 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
