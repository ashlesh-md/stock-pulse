import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/core/widgets/sp_sheet.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/orders/domain/order.dart'
    show OrderSide, ProductType;
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';

/// Contract summary with Sell and Buy; the picked side opens the ticket.
Future<void> showChainCellSheet(BuildContext context, OptionCell cell) async {
  final side = await showSpSheet<OrderSide>(
    context,
    builder: (_) => ChainCellSheet(cell: cell),
  );
  if (side == null || !context.mounted) return;
  unawaited(
    context.pushTo<void>(
      OrderTicketRoute(
        OrderTicketArgs(
          instrumentId: cell.contractId,
          side: side,
          product: ProductType.nrml,
          source: OrderSource.chain,
        ),
      ),
    ),
  );
}

/// Pops with the side the user picked.
class ChainCellSheet extends ConsumerWidget {
  const ChainCellSheet({super.key, required this.cell});
  final OptionCell cell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = context.sp;
    final orders = context.strings.orders;
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
              cell.contractId,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              Fmt.price(cell.ltp),
              style: context.spText.price.copyWith(color: sp.textPrimary),
            ),
            const SizedBox(height: SpSpace.s1),
            Text(
              context.strings.options.details(cell.oi, cell.iv, cell.delta),
              style: TextStyle(color: sp.textSecondary),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  ref
                      .read(strategyDraftControllerProvider.notifier)
                      .addFromChain(cell.contractId, OrderSide.buy, cell.ltp);
                  Navigator.of(context).pop();
                },
                icon: const Icon(AppIcons.increase),
                label: Text(context.strings.options.addToStrategy),
              ),
            ),
            const SizedBox(height: SpSpace.s4),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = ((constraints.maxWidth - SpSpace.s3) / 2)
                    .clamp(112.0, 128.0)
                    .toDouble();
                final button = FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  maximumSize: Size(width, 48),
                  padding: const EdgeInsets.symmetric(horizontal: SpSpace.s3),
                );
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: width,
                      child: FilledButton(
                        style: button.merge(
                          FilledButton.styleFrom(
                            backgroundColor: sp.sell,
                            foregroundColor: sp.onSell,
                          ),
                        ),
                        onPressed: () =>
                            Navigator.of(context).pop(OrderSide.sell),
                        child: Text(orders.sell, maxLines: 1),
                      ),
                    ),
                    const SizedBox(width: SpSpace.s3),
                    SizedBox(
                      width: width,
                      child: FilledButton(
                        style: button.merge(
                          FilledButton.styleFrom(
                            backgroundColor: sp.buy,
                            foregroundColor: sp.onAccent,
                          ),
                        ),
                        onPressed: () =>
                            Navigator.of(context).pop(OrderSide.buy),
                        child: Text(orders.buy, maxLines: 1),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
