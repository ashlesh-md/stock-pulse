import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/l10n/strings/order_strings.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/freshness.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/core/widgets/sp_picker.dart';
import 'package:stock_pulse/features/market/application/live_quote_provider.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/presentation/widgets/order_product_picker.dart';
import 'package:stock_pulse/features/market/presentation/widgets/order_summary_card.dart';
import 'package:stock_pulse/features/orders/application/order_draft.dart';
import 'package:stock_pulse/features/orders/application/order_ticket_controller.dart';
import 'package:stock_pulse/features/orders/di/order_preflight_provider.dart';
import 'package:stock_pulse/features/orders/di/order_ticket_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart'
    show OrderSide, OrderType;
import 'package:stock_pulse/features/orders/presentation/widgets/order_confirm_bar.dart';
import 'package:stock_pulse/features/orders/presentation/widgets/order_nudge_strip.dart';
import 'package:stock_pulse/features/orders/presentation/widgets/order_price_field.dart';
import 'package:stock_pulse/features/orders/presentation/widgets/order_quantity_field.dart';
import 'package:stock_pulse/features/orders/presentation/widgets/order_sheet_header.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_funds_provider.dart';
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';

/// Buy/sell form. It renders `OrderDraftController` and closes itself when
/// the order is placed; a failure stays inline above Confirm.
class OrderSheet extends ConsumerStatefulWidget {
  const OrderSheet({super.key, required this.seed});

  final OrderDraftSeed seed;

  @override
  ConsumerState<OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends ConsumerState<OrderSheet> {
  late final OrderDraft _initial = OrderDraft.fromSeed(widget.seed);
  late final _count = TextEditingController(text: '${_initial.count}');
  late final _limit = TextEditingController(text: _fixed(_initial.limitPrice));
  late final _trigger = TextEditingController(
    text: _fixed(_initial.triggerPrice),
  );

  static String _fixed(double? price) => price?.toStringAsFixed(2) ?? '';

  @override
  void dispose() {
    _count.dispose();
    _limit.dispose();
    _trigger.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final placed = await ref
        .read(orderDraftControllerProvider(widget.seed).notifier)
        .place();
    if (placed && mounted) Navigator.of(context).pop();
  }

  void _previewPayoff(OrderDraft draft) {
    ref
        .read(strategyDraftControllerProvider.notifier)
        .load(
          StrategyArgs(
            legs: [
              StrategyLeg(
                contractId: widget.seed.args.instrumentId,
                side: draft.side,
                lots: draft.count ?? 1,
                premium: draft.ltp,
              ),
            ],
          ),
        );
    unawaited(context.pushTo(const StrategyRoute()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = orderDraftControllerProvider(widget.seed);
    final draft = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final submitState = ref.watch(
      orderTicketControllerProvider(widget.seed.args.instrumentId),
    );
    final s = context.strings.orders;
    final locked = draft.submitting;
    final issues = draft.issues;
    final symbol = widget.seed.args.instrumentId;
    final funds = ref.watch(portfolioFundsProvider).value?.available;
    final instrument = ref.watch(instrumentSnapshotProvider(symbol));
    final marketClock = ref.watch(marketClockProvider).value;
    final shortOption =
        instrument?.kind == InstrumentKind.option &&
        draft.side == OrderSide.sell;
    final nudges = <String>[];
    final limit = draft.sentLimit;
    if (limit != null &&
        draft.ltp > 0 &&
        (limit - draft.ltp).abs() / draft.ltp > .03) {
      nudges.add(s.nudgeLimitFar);
    }
    if (funds != null && funds > 0 && draft.orderValue > funds * .25) {
      nudges.add(
        s.nudgeLargeOrder((draft.orderValue / funds * 100).toStringAsFixed(0)),
      );
    }
    if (instrument?.kind == InstrumentKind.option &&
        instrument?.expiry == marketClock?.tradingDay &&
        marketClock != null) {
      nudges.add(s.nudgeExpiryToday);
    }
    final underlying = instrument?.underlying;
    if (underlying != null) {
      final status = ref.watch(networkStatusProvider).value;
      final underlyingQuote = ref
          .watch(liveQuoteProvider((id: underlying, throttleMs: 500)))
          .value;
      final stale =
          status != NetworkStatus.live ||
          underlyingQuote == null ||
          freshnessOf(
                asOf: underlyingQuote.asOf,
                fromCache: underlyingQuote.fromCache,
                serverNow: ref.watch(serverClockProvider).now(),
                socketLive: status == NetworkStatus.live,
                phase: marketClock?.phase ?? MarketPhase.open,
              ) ==
              Freshness.stale;
      if (stale) nudges.add(s.nudgeUnderlyingStale);
    }
    final block = ref.watch(
      orderTicketEligibilityProvider((
        symbol: symbol,
        side: draft.side,
        type: draft.type,
        product: draft.product,
        quantity: draft.quantity,
        lots: draft.lots,
        limitPrice: draft.sentLimit,
        triggerPrice: draft.sentTrigger,
      )),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OrderSheetHeader(
          symbol: symbol,
          side: draft.side,
          openingLtp: draft.ltp,
          lotSize: draft.lotSize,
          onSide: locked ? null : controller.setSide,
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              SpSpace.s5,
              SpSpace.s4,
              SpSpace.s5,
              SpSpace.s2,
            ),
            children: [
              OrderProductPicker(
                value: draft.product,
                lotSize: draft.lotSize,
                onChanged: locked ? null : controller.setProduct,
              ),
              Text(s.orderType, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: SpSpace.s2),
              SpPicker<OrderType>(
                title: s.orderType,
                values: OrderType.values,
                label: (type) => switch (type) {
                  OrderType.market => s.market,
                  OrderType.limit => s.limit,
                  OrderType.sl => s.stopLoss,
                },
                selected: draft.type,
                enabled: !locked,
                onChanged: controller.setType,
              ),
              const SizedBox(height: SpSpace.s4),
              OrderQuantityField(
                controller: _count,
                label: draft.inLots ? s.lotsLabel : s.quantity,
                errorText: issues.contains(DraftIssue.quantity)
                    ? s.quantityInvalid
                    : null,
                onChanged: locked ? null : controller.setCount,
              ),
              if (draft.inLots)
                Padding(
                  padding: const EdgeInsets.only(top: SpSpace.s1),
                  child: Text(
                    s.unitsTotal(draft.quantity, Fmt.price(draft.orderValue)),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              if (draft.type != OrderType.market) ...[
                const SizedBox(height: SpSpace.s3),
                OrderPriceField(
                  controller: _limit,
                  label: s.limitPrice,
                  errorText: issues.contains(DraftIssue.price)
                      ? s.priceTick
                      : null,
                  onChanged: locked ? null : controller.setLimitPrice,
                ),
              ],
              if (draft.type == OrderType.sl) ...[
                const SizedBox(height: SpSpace.s3),
                OrderPriceField(
                  controller: _trigger,
                  label: s.triggerPrice,
                  errorText: issues.contains(DraftIssue.trigger)
                      ? s.triggerInvalid
                      : null,
                  onChanged: locked ? null : controller.setTriggerPrice,
                ),
              ],
              const SizedBox(height: SpSpace.s2),
              Text(
                _hint(s, draft),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              OrderNudgeStrip(messages: nudges),
              const SizedBox(height: SpSpace.s3),
              OrderSummaryCard(
                quantity: draft.quantity,
                price: draft.estimatedPrice,
                product: draft.product,
                availableFunds: funds,
                marginNotSimulated: shortOption,
              ),
              if (draft.inLots)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: locked ? null : () => _previewPayoff(draft),
                    icon: const Icon(AppIcons.chartLine),
                    label: Text(s.payoffPreview),
                  ),
                ),
            ],
          ),
        ),
        OrderConfirmBar(
          symbol: symbol,
          draft: draft,
          checkingStatus: submitState.checkingStatus,
          blockReason: block == null
              ? null
              : OrderTicketController.blockMessage(s, block),
          onConfirm: _confirm,
        ),
      ],
    );
  }
}

String _hint(OrderStrings s, OrderDraft draft) =>
    switch ((draft.type, draft.side)) {
      (OrderType.limit, OrderSide.buy) => s.limitHintBuy,
      (OrderType.limit, OrderSide.sell) => s.limitHintSell,
      (OrderType.market, OrderSide.buy) => s.marketHintBuy,
      (OrderType.market, OrderSide.sell) => s.marketHintSell,
      (OrderType.sl, _) => s.stopLossHint,
    };
