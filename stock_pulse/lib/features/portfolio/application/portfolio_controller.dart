import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/di/l10n_providers.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/pending_order.dart';
import 'package:stock_pulse/features/orders/domain/pending_order_store.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_state.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';

/// Orders + positions with live P&L.
///
/// - REST loads orders and positions.
/// - WebSocket `order` messages update an order the moment it fills or is
///   cancelled (no polling). A fill changes positions, so positions reload.
/// - Position symbols are subscribed in `ltp` mode (the smallest) because
///   P&L only needs the last price.
class PortfolioController extends AsyncNotifier<PortfolioState> {
  StreamSubscription<Object?>? _priceSub;
  StreamSubscription<List<Holding>>? _holdingsSub;
  Set<String> _priceSymbols = {};

  /// Increases on every positions reload. Two quick fills start two reloads;
  /// only the newest may write state, even if the older answer arrives last.
  int _positionsRequest = 0;

  @override
  Future<PortfolioState> build() async {
    final repo = ref.watch(portfolioRepositoryProvider);
    _priceSymbols = {};
    _holdingsSub = null;
    ref.onDispose(() => _priceSub?.cancel());
    ref.onDispose(() => _holdingsSub?.cancel());

    final orderSub = repo.orderUpdates.listen(_onOrderUpdate);
    ref.onDispose(orderSub.cancel);

    final pendingStore = await ref.read(pendingOrderStoreProvider.future);
    final (orders, positions, pendingOrders) = await (
      repo.getOrders(),
      repo.getPositions(),
      pendingStore.readAll(),
    ).wait;
    final cached = repo.current;
    final list = positions is Failure && cached != null
        ? cached.positions
        : positions.getOrThrow();
    final orderList = orders is Failure && cached != null
        ? const <Order>[]
        : orders.getOrThrow();
    final reconciledOrders = _reconcilePending(
      orderList,
      pendingOrders,
      pendingStore,
    );
    final holdings = cached?.holdings ?? const <Holding>[];
    final symbols = {
      for (final position in list)
        if (position.quantity != 0) position.symbol,
      for (final holding in holdings) holding.symbol,
    };
    final quotes = {
      for (final quote
          in ref.read(marketRepositoryProvider).latestQuotes(symbols))
        quote.symbol: quote,
    };
    if (ref.mounted) _watchPrices(list, holdings: holdings);
    return PortfolioState(
      orders: reconciledOrders,
      positions: list,
      holdings: holdings,
      quotes: quotes,
      ltp: {for (final entry in quotes.entries) entry.key: entry.value.ltp},
    );
  }

  /// Cancels an open order; a failure shows a snackbar.
  Future<void> cancel(String orderId) async {
    final result = await ref
        .read(portfolioRepositoryProvider)
        .cancelOrder(orderId);
    if (!ref.mounted) return;
    if (result case Failure()) {
      ref
          .read(feedbackControllerProvider.notifier)
          .show(
            FeedbackMessage(
              key: 'portfolio.cancelFailed.$orderId',
              text: ref.read(stringsProvider).portfolio.cancelFailed,
              kind: FeedbackKind.error,
            ),
          );
    }
  }

  Future<void> refreshPendingStatus(Order pending) async {
    final key = pending.clientKey;
    if (pending.status != OrderStatus.pending || key == null) return;
    final result = await ref
        .read(orderRepositoryProvider)
        .getOrder(clientKey: key);
    if (!ref.mounted) return;
    if (result case Success(value: final Order resolved?)) {
      final store = await ref.read(pendingOrderStoreProvider.future);
      await store.remove(key);
      final current = state.value;
      if (current == null) return;
      state = AsyncData(
        current.copyWith(
          orders: [
            for (final existing in current.orders)
              if (existing.clientKey != key) existing,
            resolved,
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        ),
      );
    }
  }

  Future<void> loadHoldings() async {
    final current = state.value;
    if (current == null || current.loadingHoldings) return;
    state = AsyncData(
      current.copyWith(loadingHoldings: true, holdingsFailed: false),
    );
    final result = await ref.read(portfolioRepositoryProvider).getHoldings();
    if (!ref.mounted) return;
    state = AsyncData(switch (result) {
      Success(:final value) => state.requireValue.copyWith(
        holdings: value,
        loadingHoldings: false,
      ),
      Failure() => state.requireValue.copyWith(
        loadingHoldings: false,
        holdingsFailed: state.requireValue.holdings.isEmpty,
      ),
    });
    _watchPrices(
      state.requireValue.positions,
      holdings: state.requireValue.holdings,
    );
    _holdingsSub ??= ref
        .read(portfolioRepositoryProvider)
        .watchHoldings()
        .listen((holdings) {
          final current = state.value;
          if (current == null) return;
          state = AsyncData(current.copyWith(holdings: holdings));
          _watchPrices(current.positions, holdings: current.holdings);
        });
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> _onOrderUpdate(Order order) async {
    final pendingKey = order.clientKey;
    if (pendingKey != null) {
      final store = await ref.read(pendingOrderStoreProvider.future);
      unawaited(store.remove(pendingKey));
    }
    final current = state.value;
    if (current == null) return;
    final previous = current.orders
        .where(
          (o) =>
              o.id == order.id ||
              (pendingKey != null && o.clientKey == pendingKey),
        )
        .firstOrNull;
    if (previous != null &&
        (previous.version > order.version ||
            previous.updatedAt.isAfter(order.updatedAt))) {
      return;
    }
    final exists = previous != null;
    state = AsyncData(
      current.copyWith(
        orders: exists
            ? [
                for (final o in current.orders)
                  o.id == order.id ||
                          (pendingKey != null && o.clientKey == pendingKey)
                      ? order
                      : o,
              ]
            : [order, ...current.orders],
      ),
    );
    if (order.status != OrderStatus.complete) return;

    final request = ++_positionsRequest;
    final result = await ref.read(portfolioRepositoryProvider).getPositions();
    if (!ref.mounted || request != _positionsRequest) return;
    if (result case Success(value: final positions)) {
      state = AsyncData(state.requireValue.copyWith(positions: positions));
      _watchPrices(positions);
    }
  }

  List<Order> _reconcilePending(
    List<Order> serverOrders,
    List<PendingOrder> pending,
    PendingOrderStore store,
  ) {
    final orders = [...serverOrders];
    for (final item in pending) {
      final match = orders.indexWhere((o) => o.clientKey == item.clientKey);
      if (match < 0) {
        orders.add(item.toOrder());
      } else {
        unawaited(store.remove(item.clientKey));
      }
    }
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  /// (Re)subscribes when the set of position symbols changes.
  void _watchPrices(List<Position> positions, {List<Holding>? holdings}) {
    final symbols = {
      for (final h in holdings ?? state.value?.holdings ?? const <Holding>[])
        h.symbol,
      for (final p in positions)
        if (p.quantity != 0) p.symbol,
    };
    if (setEquals(symbols, _priceSymbols)) return;
    _priceSymbols = symbols;
    unawaited(_priceSub?.cancel());
    _priceSub = null;
    if (symbols.isEmpty) return;
    _priceSub = ref
        .read(marketRepositoryProvider)
        .watchQuotes(symbols.toList(), FeedMode.ltp)
        .listen((batch) {
          final current = state.value;
          if (current == null) return;
          state = AsyncData(
            current.copyWith(
              quotes: {...current.quotes, for (final q in batch) q.symbol: q},
              ltp: {...current.ltp, for (final q in batch) q.symbol: q.ltp},
            ),
          );
        });
  }
}
