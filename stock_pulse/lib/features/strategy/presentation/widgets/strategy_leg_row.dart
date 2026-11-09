import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/lot_stepper.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';

class StrategyLegRow extends ConsumerWidget {
  const StrategyLegRow({super.key, required this.leg, required this.index});
  final StrategyLeg leg;
  final int index;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(strategyDraftControllerProvider.notifier);
    final s = context.strings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(leg.contractId, style: Theme.of(context).textTheme.titleSmall),
            Text(Fmt.price(leg.premium)),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<OrderSide>(
                  segments: [
                    ButtonSegment(
                      value: OrderSide.buy,
                      label: Text(s.orders.buy),
                    ),
                    ButtonSegment(
                      value: OrderSide.sell,
                      label: Text(s.orders.sell),
                    ),
                  ],
                  selected: {leg.side},
                  onSelectionChanged: (value) =>
                      controller.update(index, side: value.single),
                ),
                LotStepper(
                  value: leg.lots,
                  max: 100,
                  onChanged: (lots) => controller.update(index, lots: lots),
                ),
                TextButton(
                  onPressed: () => unawaited(
                    context.pushTo<void>(
                      OrderTicketRoute(
                        OrderTicketArgs(
                          instrumentId: leg.contractId,
                          side: leg.side,
                          lots: leg.lots,
                        ),
                      ),
                    ),
                  ),
                  child: Text(s.strategy.trade),
                ),
                IconButton(
                  tooltip: s.strategy.remove,
                  onPressed: () => controller.remove(index),
                  icon: const Icon(AppIcons.close),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
