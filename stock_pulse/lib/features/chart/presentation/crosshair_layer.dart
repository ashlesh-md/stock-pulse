import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/sp_sheet.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';
import 'package:stock_pulse/features/alerts/presentation/widgets/create_alert_form.dart';
import 'package:stock_pulse/features/chart/di/chart_providers.dart';
import 'package:stock_pulse/features/chart/di/drawings_providers.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/tick_snap.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/presentation/widgets/show_order_sheet.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';

class ChartPriceActions extends ConsumerWidget {
  const ChartPriceActions({super.key, required this.instrumentId});
  final String instrumentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crosshair = ref.watch(
      chartControllerProvider(instrumentId)
          .select((state) => state.value?.crosshairIndex),
    );
    final drawings = ref.watch(drawingsControllerProvider(instrumentId));
    final selected = drawings.drawings.where(
      (drawing) => drawing.id == drawings.selectedId,
    );
    final selectedDrawing = selected.isEmpty ? null : selected.first;
    final linePrice = selectedDrawing?.kind == DrawingKind.horizontal
        ? selectedDrawing!.start.price
        : null;
    final crosshairPrice = ref.watch(
      chartReadoutProvider(instrumentId).select((value) => value.$1?.close),
    );
    final price = linePrice ?? (crosshair == null ? null : crosshairPrice);
    // A selected line can outlive a stock-page reload; the actions need the
    // loaded instrument and quote.
    final loaded = ref.watch(
      stockDetailControllerProvider(instrumentId).select((v) => v.hasValue),
    );
    return price == null || !loaded
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: CrosshairLayer(instrumentId: instrumentId, price: price),
          );
  }
}

/// Context actions for a crosshair value or selected horizontal drawing.
class CrosshairLayer extends ConsumerWidget {
  const CrosshairLayer({
    super.key,
    required this.instrumentId,
    required this.price,
  });

  final String instrumentId;
  final double price;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(
      stockDetailControllerProvider(instrumentId)
          .select((value) => value.value!),
    );
    final chartStrings = context.strings.chart;
    final isIndex = detail.instrument.kind == InstrumentKind.marketIndex;
    final condition = price >= detail.quote.ltp
        ? AlertCondition.above
        : AlertCondition.below;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        OutlinedButton.icon(
          onPressed: () => showSpSheet<void>(
            context,
            builder: (_) => CreateAlertForm(
              initialSymbol: instrumentId,
              initialPrice: price,
              initialCondition: condition,
            ),
          ),
          icon: const Icon(AppIcons.notifications),
          label: Text(chartStrings.setAlert),
        ),
        if (!isIndex)
          for (final side in OrderSide.values)
            OutlinedButton.icon(
              onPressed: () {
                final tickSize = detail.instrument.tickSize;
                final snapped = snapToTick(price, tickSize);
                final args = OrderTicketArgs(
                  instrumentId: instrumentId,
                  side: side,
                  limitPrice: snapped,
                  source: OrderSource.chart,
                );
                unawaited(
                  showOrderSheet(context, (
                    args: args,
                    lotSize: detail.instrument.lotSize,
                    tickSize: tickSize,
                    ltp: detail.quote.ltp,
                  )),
                );
              },
              icon: Icon(
                side == OrderSide.buy
                    ? AppIcons.buyAtPrice
                    : AppIcons.sellAtPrice,
              ),
              label: Text(
                side == OrderSide.buy
                    ? chartStrings.buyLimit
                    : chartStrings.sellLimit,
              ),
            ),
      ],
    );
  }
}
