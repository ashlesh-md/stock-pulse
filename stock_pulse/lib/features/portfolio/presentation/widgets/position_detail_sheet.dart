import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/core/widgets/sp_sheet.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';

/// Shows the P&L breakdown; Buy more or Exit opens the order ticket
/// prefilled from the caller's context, after the sheet has closed.
Future<void> showPositionDetails(
  BuildContext context, {
  required Position position,
}) async {
  final action = await showSpSheet<PositionAction>(
    context,
    builder: (_) => PositionDetailSheet(position: position),
  );
  if (action == null || !context.mounted) return;
  final exit = action == PositionAction.exit;
  unawaited(
    context.pushTo(
      OrderTicketRoute(
        OrderTicketArgs(
          instrumentId: position.symbol,
          side: exit && position.quantity > 0 ? OrderSide.sell : OrderSide.buy,
          lots: exit ? (position.lots ?? position.quantity).abs() : null,
          product: position.product,
          source: OrderSource.position,
        ),
      ),
    ),
  );
}

enum PositionAction { buyMore, exit }

/// Pops with the [PositionAction] the user picked.
class PositionDetailSheet extends ConsumerWidget {
  const PositionDetailSheet({super.key, required this.position});
  final Position position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings.portfolio;
    final sp = context.sp;
    final ltp = ref.watch(
      portfolioControllerProvider.select((a) => a.value?.ltp[position.symbol]),
    );
    final qty = position.quantity;
    final invested = position.averagePrice * qty.abs();
    final pnl = ltp == null ? null : position.unrealizedPnl(ltp);
    final noValue = context.strings.common.noValue;
    Widget row(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: SpSpace.s2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: sp.textSecondary)),
          ),
          Text(
            value,
            style: context.spText.price.copyWith(
              color: color ?? sp.textPrimary,
            ),
          ),
        ],
      ),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SpSpace.s5,
          0,
          SpSpace.s5,
          SpSpace.s4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              position.symbol,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: SpSpace.s2),
            row(s.quantity, '$qty'),
            row(s.averagePrice, Fmt.price(position.averagePrice)),
            row(s.lastPrice, ltp == null ? noValue : Fmt.price(ltp)),
            row(s.invested, Fmt.price(invested)),
            row(
              s.currentValue,
              ltp == null ? noValue : Fmt.price(ltp * qty.abs()),
            ),
            const Divider(),
            row(
              s.unrealisedLive,
              pnl == null
                  ? noValue
                  : s.pnlPercent(
                      Fmt.signed(pnl),
                      Fmt.percent(invested == 0 ? 0 : pnl / invested * 100),
                    ),
              color: pnl == null ? null : sp.directionOf(pnl),
            ),
            row(
              s.realised,
              Fmt.signed(position.realizedPnl),
              color: sp.directionOf(position.realizedPnl),
            ),
            const SizedBox(height: SpSpace.s4),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(SpDensity.confirm),
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(PositionAction.buyMore),
                    child: Text(s.buyMore),
                  ),
                ),
                const SizedBox(width: SpSpace.s3),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(SpDensity.confirm),
                    ),
                    onPressed: qty == 0
                        ? null
                        : () => Navigator.of(context).pop(PositionAction.exit),
                    child: Text(s.exit),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
