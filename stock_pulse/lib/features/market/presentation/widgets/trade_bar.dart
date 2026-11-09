import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/presentation/widgets/show_order_sheet.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';

/// BUY and SELL buttons that open the order sheet.
class TradeBar extends ConsumerWidget {
  const TradeBar({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final instrument = ref.watch(
      stockDetailControllerProvider(instrumentId)
          .select((s) => s.requireValue.instrument),
    );
    final strings = context.strings.orders;
    void open(OrderSide side) {
      final args = OrderTicketArgs(instrumentId: instrumentId, side: side);
      if (instrument.kind == InstrumentKind.option) {
        unawaited(context.pushTo(OrderTicketRoute(args)));
        return;
      }
      final ltp = ref
          .read(stockDetailControllerProvider(instrumentId))
          .requireValue
          .quote
          .ltp;
      unawaited(
        showOrderSheet(context, (
          args: args,
          lotSize: instrument.lotSize,
          tickSize: instrument.tickSize,
          ltp: ltp,
        )),
      );
    }

    if (instrument.kind == InstrumentKind.marketIndex) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: () =>
                context.goTo(OptionChainRoute(underlying: instrumentId)),
            child: Text(context.strings.shell.options),
          ),
        ),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.sp.buy,
                  foregroundColor: context.sp.onAccent,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => open(OrderSide.buy),
                child: Text(strings.buy),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.sp.sell,
                  foregroundColor: context.sp.onSell,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () => open(OrderSide.sell),
                child: Text(strings.sell),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
