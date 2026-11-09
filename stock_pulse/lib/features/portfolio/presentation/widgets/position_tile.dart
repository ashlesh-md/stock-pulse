import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';

/// One position with its live P&L. It selects only its own price, so a tick
/// for another symbol does not rebuild it.
class PositionTile extends ConsumerWidget {
  const PositionTile({super.key, required this.position, this.onTap});

  final Position position;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.portfolio;
    final price = ref.watch(
      portfolioControllerProvider.select((a) => a.value?.ltp[position.symbol]),
    );
    final pnl = price == null ? null : position.unrealizedPnl(price);
    final qty = position.quantity;
    final average = Fmt.number(position.averagePrice);
    return ListTile(
      minTileHeight: SpDensity.positionRow,
      onTap: onTap,
      title: Text(position.symbol),
      subtitle: Text(switch (qty) {
        0 => strings.closedRealised(Fmt.signed(position.realizedPnl)),
        > 0 => strings.longPosition(qty, average),
        _ => strings.shortPosition(qty.abs(), average),
      }),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (price != null) Text(strings.ltp(Fmt.number(price))),
              if (pnl != null && qty != 0)
                Text(
                  Fmt.signed(pnl),
                  style: TextStyle(
                    color: context.sp.directionOf(pnl),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (onTap != null)
            Icon(AppIcons.chevronRight, color: context.sp.textTertiary),
        ],
      ),
    );
  }
}
