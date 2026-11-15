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
import 'package:stock_pulse/core/l10n/app_strings.dart';
import 'package:stock_pulse/core/l10n/di/l10n_providers.dart';
import 'package:stock_pulse/core/l10n/strings/order_strings.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/orders/application/order_ticket_state.dart';
import 'package:stock_pulse/features/orders/application/ticket_block_message.dart';
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

  /// True once the request may have reached the server; until then a
  /// failure can drop the key safely.
  bool _sent = false;

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
    // An uncertain order blocks the ticket until the server says what became
    // of it. Once it does, the same order is reported, never sent again.
    if (state.uncertain || (_pending != null && _pending != draft)) {
      final same = _pending == draft;
      state = state.copyWith(submitting: true);
      Order? settled;
      try {
        settled = await _settledPending();
      } on Object {
        settled = null;
      }
      if (settled == null) {
        if (ref.mounted) state = state.copyWith(submitting: false);
        return strings.orders.pendingPrevious;
      }
      if (same) {
        _announcePlaced(settled, strings);
        return null;
      }
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
        return ticketBlockMessage(strings.orders, block);
      }
    }
    _pending = draft;
    _key ??= List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    state = const OrderTicketState(submitting: true);
    _sent = false;
    try {
      return await _send(draft, strings);
    } on Object {
      if (!_sent) {
        // Nothing reached the server: forget the key so the next tap is a
        // fresh order instead of a wait on one that never existed.
        _key = null;
        _pending = null;
        if (ref.mounted) state = const OrderTicketState();
        return strings.orders.notPlaced(strings.errors.unknown);
      }
      // It may have been placed: keep the key, so a retry can never place a
      // second order.
      if (ref.mounted) state = const OrderTicketState(uncertain: true);
      return strings.orders.orderStatusUnknown;
    }
  }

  Future<String?> _send(_Draft draft, AppStrings strings) async {
    final request = OrderRequest(
      symbol: symbol,
      side: draft.side,
      type: draft.type,
      quantity: draft.quantity,
      limitPrice: draft.limitPrice,
      product: draft.product,
      lots: draft.lots,
      triggerPrice: draft.triggerPrice,
    );
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
              request: request,
              createdAt: DateTime.now().toUtc(),
            ),
          ),
        );
    _log(
      Events.orderSubmitted(
        kind: draft.type.name,
        product: draft.product.name,
        source: 'manual',
      ),
    );
    _sent = true;
    final result = await _placeAndCheck(request);
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
        _announcePlaced(order, strings);
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

  /// The uncertain order once the server knows it, which frees the ticket;
  /// null while it is still unknown.
  Future<Order?> _settledPending() async {
    final key = _key;
    if (key == null) return null;
    final lookup = await ref
        .read(orderRepositoryProvider)
        .getOrder(clientKey: key);
    if (lookup case Success(value: final Order order?)
        when order.clientKey == key) {
      await ref
          .read(pendingOrderStoreProvider.future)
          .then((store) => store.remove(key));
      _key = null;
      _pending = null;
      if (ref.mounted) state = const OrderTicketState();
      return order;
    }
    return null;
  }

  void _announcePlaced(Order order, AppStrings strings) => ref
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
}
