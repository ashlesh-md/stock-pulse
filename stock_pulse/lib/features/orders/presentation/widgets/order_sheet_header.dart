import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/core/widgets/segmented_choice.dart';
import 'package:stock_pulse/features/market/application/live_quote_provider.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;

/// Side-tinted top of the order sheet: symbol, live price, lot size and the
/// BUY | SELL switch.
class OrderSheetHeader extends ConsumerWidget {
  const OrderSheetHeader({
    super.key,
    required this.symbol,
    required this.side,
    required this.openingLtp,
    required this.lotSize,
    required this.onSide,
  });

  final String symbol;
  final OrderSide side;
  final double openingLtp;
  final int lotSize;

  /// Null locks the switch while the order is being placed.
  final ValueChanged<OrderSide>? onSide;

  static const _throttleMs = 500;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = context.sp;
    final s = context.strings.orders;
    final ltp =
        ref.watch(
          liveQuoteProvider((id: symbol, throttleMs: _throttleMs))
              .select((q) => q.value?.ltp),
        ) ??
        openingLtp;
    final tone = side == OrderSide.buy ? sp.buy : sp.sell;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        SpSpace.s5,
        SpSpace.s3,
        SpSpace.s5,
        SpSpace.s3,
      ),
      decoration: BoxDecoration(color: tone.withValues(alpha: .12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  symbol,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                Fmt.price(ltp),
                style: context.spText.price.copyWith(color: sp.textPrimary),
              ),
            ],
          ),
          if (lotSize > 1)
            Text(
              s.lotSizeLine(lotSize),
              style: text.bodySmall?.copyWith(color: sp.textSecondary),
            ),
          const SizedBox(height: SpSpace.s2),
          SegmentedChoice<OrderSide>(
            segments: [
              SpSegment(OrderSide.buy, s.buy),
              SpSegment(OrderSide.sell, s.sell),
            ],
            selected: side,
            onChanged: onSide,
          ),
        ],
      ),
    );
  }
}
