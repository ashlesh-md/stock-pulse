import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_event.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/di/l10n_providers.dart';
import 'package:stock_pulse/core/l10n/strings/order_strings.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/orders/application/order_ticket_state.dart';
import 'package:stock_pulse/features/orders/di/order_preflight_provider.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart'
    show Order, OrderSide, OrderStatus, OrderType, ProductType;
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/pending_order.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';
import 'package:stock_pulse/features/orders/domain/ticket_validation.dart';
import 'package:stock_pulse/features/portfolio/application/order_summary.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_section.dart';

typedef _Draft = ({
  OrderSide side,
  OrderType type,
  int quantity,
  double? limitPrice,
  ProductType product,
  int? lots,
  double? triggerPrice,
});

/// Keeps an uncertain submission's key across sheet dismissal and retries.
class OrderTicketController extends Notifier<OrderTicketState> {
  OrderTicketController(this.symbol);
  final String symbol;
  String? _key;
  _Draft? _pending;

  static const _maxRetries = 2;
  static const _checkStatusAfter = Duration(seconds: 3);

  void _log(AnalyticsEvent event) {
    if (ref.read(localPrefsProvider).value?.data.analyticsConsent ?? false) {
      ref.read(analyticsProvider).log(event);
    }
  }

  @override
  OrderTicketState build() => const OrderTicketState();

  Future<String?> submit({
    required OrderSide side,
    required OrderType type,
    required int quantity,
    double? limitPrice,
    ProductType product = ProductType.cnc,
    int? lots,
    double? triggerPrice,
  }) async {
    final strings = ref.read(stringsProvider);
    if (state.submitting) return strings.orders.submitting;
    if (state.uncertain) return strings.orders.pendingPrevious;
    _log(Events.orderConfirmTapped(type.name));
    final draft = (
      side: side,
      type: type,
      quantity: quantity,
      limitPrice: limitPrice,
      product: product,
      lots: lots,
      triggerPrice: triggerPrice,
    );
    if (_pending != null && _pending != draft) {
      return strings.orders.pendingPrevious;
    }
    if (_pending == null) {
      final block = ref.read(orderPreflightProvider)(
        symbol: symbol,
        side: side,
        type: type,
        product: product,
        quantity: quantity,
        lots: lots,
        limitPrice: limitPrice,
        triggerPrice: triggerPrice,
      );
      if (block != null) {
        if (block == TicketBlock.unavailable) {
          _log(Events.orderBlockedStale);
        }
        return blockMessage(strings.orders, block);
      }
    }
    _pending = draft;
    _key ??= List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    state = const OrderTicketState(submitting: true);
    final statusTimer = Timer(_checkStatusAfter, () {
      if (ref.mounted && state.submitting) {
        state = state.copyWith(checkingStatus: true);
      }
    });
    final key = _key!;
    await ref
        .read(pendingOrderStoreProvider.future)
        .then(
          (store) => store.put(
            PendingOrder(
              clientKey: key,
              request: OrderRequest(
                symbol: symbol,
                side: side,
                type: type,
                quantity: quantity,
                limitPrice: limitPrice,
                product: product,
                lots: lots,
                triggerPrice: triggerPrice,
              ),
              createdAt: DateTime.now().toUtc(),
            ),
          ),
        );
    _log(
      Events.orderSubmitted(
        kind: type.name,
        product: product.name,
        source: 'manual',
      ),
    );
    final result = await _placeAndCheck(
      OrderRequest(
        symbol: symbol,
        side: side,
        type: type,
        quantity: quantity,
        limitPrice: limitPrice,
        product: product,
        lots: lots,
        triggerPrice: triggerPrice,
      ),
    );
    statusTimer.cancel();
    if (!ref.mounted) return strings.orders.pendingPrevious;
    _log(
      Events.orderResult(
        switch (result) {
          PlaceAcked(:final order) =>
            order.status == OrderStatus.complete ? 'filled' : 'unknown',
          PlaceRejected() => 'rejected',
          PlaceTimedOut() => 'unknown',
        },
        switch (result) {
          PlaceAcked() => 'ok',
          PlaceRejected(:final code) => code,
          PlaceTimedOut() => 'unavailable',
        },
      ),
    );
    switch (result) {
      case PlaceAcked(:final order):
        await ref
            .read(pendingOrderStoreProvider.future)
            .then((store) => store.remove(key));
        _key = null;
        _pending = null;
        state = const OrderTicketState();
        ref
            .read(feedbackControllerProvider.notifier)
            .show(
              FeedbackMessage(
                key: 'orders.placed.${order.id}',
                text: strings.orders.withId(
                  order.id,
                  orderSummary(order, strings.orders),
                ),
                kind: FeedbackKind.success,
              ),
            );
        return null;
      case PlaceRejected(:final code, :final message):
        await ref
            .read(pendingOrderStoreProvider.future)
            .then((store) => store.remove(key));
        _key = null;
        _pending = null;
        state = const OrderTicketState();
        return strings.orders.notPlaced(
          rejectionText(
            strings.orders,
            strings.errors,
            ServerError(400, code, message),
          ),
        );
      case PlaceTimedOut():
        state = const OrderTicketState(uncertain: true);
        ref
            .read(feedbackControllerProvider.notifier)
            .show(
              FeedbackMessage(
                key: 'orders.status_unknown.$_key',
                text: strings.orders.orderStatusUnknown,
                actionLabel: strings.orders.viewOrders,
                action: OpenLocation(
                  const PortfolioRoute(section: PortfolioSection.orders)
                      .location,
                ),
                persist: true,
                priority: FeedbackPriority.orderOutcome,
              ),
            );
        return null;
    }
  }

  Future<PlaceOutcome> _placeAndCheck(OrderRequest request) async {
    final repository = ref.read(orderRepositoryProvider);
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      final result = await repository.place(request, idempotencyKey: _key!);
      if (result case PlaceAcked() || PlaceRejected()) return result;
      final lookup = await repository.getOrder(clientKey: _key);
      if (lookup case Success(value: final Order order?)
          when order.clientKey == _key) {
        return PlaceAcked(order);
      }
    }
    return const PlaceTimedOut();
  }

  static String blockMessage(OrderStrings strings, TicketBlock block) =>
      switch (block) {
        TicketBlock.unavailable => strings.blockUnavailable,
        TicketBlock.closed => strings.blockClosed,
        TicketBlock.preOpen => strings.blockPreOpen,
        TicketBlock.instrument => strings.rejectedSymbol,
        TicketBlock.quantity => strings.rejectedQuantity,
        TicketBlock.price => strings.rejectedPrice,
        TicketBlock.trigger => strings.blockTrigger,
        TicketBlock.product => strings.blockProduct,
        TicketBlock.expired => strings.blockExpired,
        TicketBlock.cutoff => strings.blockCutoff,
        TicketBlock.risk => strings.blockRisk,
        TicketBlock.funds => strings.blockFunds,
      };
}
