import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/features/market/application/stock_detail_state.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/presentation/widgets/show_order_sheet.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';

class ChartTradeRail extends ConsumerWidget {
  const ChartTradeRail({super.key, required this.instrumentId});

  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(
      stockDetailControllerProvider(instrumentId)
          .select((state) => state.value),
    );
    if (detail == null ||
        detail.instrument.kind == InstrumentKind.marketIndex) {
      return const SizedBox.shrink();
    }
    final labels = context.strings.orders;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TradeButton(
          label: labels.buy,
          color: context.sp.buy,
          foreground: context.sp.onAccent,
          onPressed: () => _open(ref, OrderSide.buy, detail),
        ),
        _TradeButton(
          label: labels.sell,
          color: context.sp.sell,
          foreground: context.sp.onSell,
          onPressed: () => _open(ref, OrderSide.sell, detail),
        ),
      ],
    );
  }

  void _open(WidgetRef ref, OrderSide side, StockDetailState detail) {
    final args = OrderTicketArgs(
      instrumentId: instrumentId,
      side: side,
      source: OrderSource.chart,
    );
    ref.read(analyticsProvider).log(Events.orderSheetOpened('chart'));
    unawaited(
      showOrderSheet(ref.context, (
        args: args,
        lotSize: detail.instrument.lotSize,
        tickSize: detail.instrument.tickSize,
        ltp: detail.quote.ltp,
      )),
    );
  }
}

class _TradeButton extends StatelessWidget {
  const _TradeButton({
    required this.label,
    required this.color,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    child: SizedBox(
      width: 52,
      height: 38,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          padding: EdgeInsets.zero,
          textStyle: Theme.of(context).textTheme.labelSmall,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    ),
  );
}
