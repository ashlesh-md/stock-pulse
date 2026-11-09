part of 'broker.dart';

extension BrokerLifecycle on Broker {
  void closePosition(
    Position position,
    double price, {
    required String reason,
  }) {
    final order = Order(
      id: 'ORD${(_nextId++).toString().padLeft(6, '0')}',
      symbol: position.symbol,
      side: position.quantity > 0 ? OrderSide.sell : OrderSide.buy,
      type: OrderType.market,
      quantity: position.quantity.abs(),
      limitPrice: null,
      product: position.product,
      createdAt: _clock(),
      version: ++_version,
    )..reason = reason;
    _orders.add(order);
    _fill(order, price);
  }

  void reset() {
    _orders.clear();
    _positions.clear();
    _holdings.clear();
    _pendingDeliveries.clear();
    _byIdempotencyKey.clear();
    _version++;
  }

  /// Transfers prior-session CNC fills to settled holdings at the 09:00 roll.
  void settleDelivery(BoundaryEvent event) {
    final settled = _pendingDeliveries
        .where((fill) => fill.filledAt.isBefore(event.at))
        .toList();
    if (settled.isEmpty) return;
    _pendingDeliveries.removeWhere(settled.contains);
    for (final fill in settled) {
      final holding = _holdings.putIfAbsent(
        '${fill.symbol}|cnc',
        () => Position(fill.symbol, product: ProductType.cnc),
      )..apply(OrderSide.buy, fill.quantity, fill.price);
      holding.version = ++_version;
    }
    _positions.removeWhere((key, _) => key.endsWith('|cnc'));
    for (final fill in _pendingDeliveries) {
      _positions
          .putIfAbsent(
            '${fill.symbol}|cnc',
            () => Position(fill.symbol, product: ProductType.cnc),
          )
          .apply(OrderSide.buy, fill.quantity, fill.price);
    }
  }

  int _availableHoldingQuantity(String symbol) {
    final settled = _holdings['$symbol|cnc']?.quantity ?? 0;
    final reserved = _orders
        .where(
          (order) =>
              order.symbol == symbol &&
              order.product == ProductType.cnc &&
              order.side == OrderSide.sell &&
              {
                OrderStatus.open,
                OrderStatus.queued,
                OrderStatus.triggerPending,
              }.contains(order.status),
        )
        .fold<int>(0, (sum, order) => sum + order.quantity);
    return settled - reserved;
  }
}

class _PendingDelivery {
  const _PendingDelivery(this.symbol, this.quantity, this.price, this.filledAt);

  final String symbol;
  final int quantity;
  final double price;
  final DateTime filledAt;
}
