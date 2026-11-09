import 'dart:async';

import 'package:market_server/src/broker_errors.dart';
import 'package:market_server/src/clock_scheduler.dart';
import 'package:market_server/src/market_calendar.dart';
import 'package:market_server/src/market_engine.dart';
import 'package:market_server/src/models.dart';

export 'package:market_server/src/broker_errors.dart';

part 'broker_lifecycle.dart';

class Broker {
  Broker(this._engine, {DateTime Function()? clock})
    : _clock = clock ?? (() => DateTime.now().toUtc()) {
    _tickSub = _engine.ticks.listen(_matchOpenOrders);
  }

  final MarketEngine _engine;
  final DateTime Function() _clock;
  late final StreamSubscription<Set<String>> _tickSub;

  final List<Order> _orders = [];
  final Map<String, Position> _positions = {};
  final Map<String, Position> _holdings = {};
  final List<_PendingDelivery> _pendingDeliveries = [];
  final Map<String, Order> _byIdempotencyKey = {};
  final _updates = StreamController<Order>.broadcast(sync: true);
  double Function()? availableFunds;
  int _nextId = 1;
  int _version = 0;

  Order? byClientKey(String key) => _byIdempotencyKey[key];

  Stream<Order> get updates => _updates.stream;
  List<Order> get orders => List.unmodifiable(_orders.reversed);
  List<Position> get positions => _positions.values
      .where((p) => p.quantity != 0 || p.realizedPnl != 0)
      .toList();
  List<Position> get holdings => List.unmodifiable(
    _holdings.values.where((holding) => holding.quantity > 0),
  );

  Order place({
    required String symbol,
    required OrderSide side,
    required OrderType type,
    required int quantity,
    double? limitPrice,
    String? idempotencyKey,
    ProductType product = ProductType.mis,
    int? lots,
    double? triggerPrice,
  }) {
    if (idempotencyKey != null) {
      final existing = _byIdempotencyKey[idempotencyKey];
      if (existing != null) return existing;
    }
    final stock = _engine[symbol];
    if (stock == null) {
      throw OrderRejection(
        'unknown_symbol',
        'No instrument "$symbol"',
        status: 404,
      );
    }
    if (!stock.instrument.tradable) {
      throw const OrderRejection('not_tradable', 'Indices cannot be ordered');
    }
    if (stock.instrument.kind == InstrumentKind.option) {
      if (lots == null || lots <= 0) {
        throw const OrderRejection(
          'invalid_lots',
          'Options require positive lots',
        );
      }
      quantity = lots * stock.instrument.lotSize;
    }
    if (product == ProductType.cnc &&
        side == OrderSide.sell &&
        quantity > _availableHoldingQuantity(symbol)) {
      throw const OrderRejection(
        'insufficient_holdings',
        'Cannot sell more delivery shares than held',
      );
    }
    if (type == OrderType.sl &&
        (triggerPrice == null || !triggerPrice.isFinite || triggerPrice <= 0)) {
      throw const OrderRejection(
        'invalid_trigger',
        'Stop loss needs a positive trigger price',
      );
    }
    final isOption = stock.instrument.kind == InstrumentKind.option;
    if (isOption ? product == ProductType.cnc : product == ProductType.nrml) {
      throw const OrderRejection(
        'invalid_product',
        'Product does not support this instrument',
      );
    }
    final expiry = stock.instrument.expiry;
    if (expiry != null &&
        !_clock().isBefore(DateTime.parse('${expiry}T10:00:00Z'))) {
      throw const OrderRejection('contract_expired', 'Contract has expired');
    }
    if (_engine.phase == MarketPhase.closed) {
      throw const OrderRejection('market_closed', 'Market is closed');
    }
    if (_engine.phase == MarketPhase.preOpen &&
        (isOption || type != OrderType.limit)) {
      throw const OrderRejection(
        'preopen_not_allowed',
        'Only equity limit orders in pre-open',
      );
    }
    if (side == OrderSide.buy &&
        availableFunds != null &&
        quantity * (limitPrice ?? stock.bestAsk) > availableFunds!()) {
      throw const OrderRejection(
        'insufficient_funds',
        'Not enough available funds',
      );
    }
    if (quantity <= 0 || quantity > 10000) {
      throw const OrderRejection(
        'invalid_quantity',
        'Quantity must be 1–10000',
      );
    }
    if (type != OrderType.market) {
      if (limitPrice == null || !limitPrice.isFinite || limitPrice <= 0) {
        throw const OrderRejection(
          'invalid_price',
          'A limit order needs a positive price',
        );
      }
      // Exchanges reject prices far from the market (price bands/circuits).
      final ticks = limitPrice / stock.instrument.tickSize;
      if ((ticks - ticks.round()).abs() > 1e-6) {
        throw const OrderRejection(
          'invalid_tick',
          'Price must be on the instrument tick grid',
        );
      }
      final band = stock.instrument.bandFor(stock.prevClose);
      if (band != null && (limitPrice < band.low || limitPrice > band.high)) {
        throw const OrderRejection(
          'price_out_of_band',
          'Price is outside the 20% band',
        );
      }
    }

    final order = Order(
      id: 'ORD${(_nextId++).toString().padLeft(6, '0')}',
      symbol: symbol,
      side: side,
      type: type,
      quantity: quantity,
      limitPrice: type != OrderType.market ? limitPrice : null,
      product: product,
      lots: lots,
      triggerPrice: triggerPrice,
      clientKey: idempotencyKey,
      version: ++_version,
      createdAt: _clock(),
    );
    _orders.add(order);
    if (idempotencyKey != null) _byIdempotencyKey[idempotencyKey] = order;

    if (_engine.phase == MarketPhase.preOpen) {
      order.status = OrderStatus.queued;
      _updates.add(order);
    } else if (type == OrderType.sl) {
      order.status = OrderStatus.triggerPending;
      _updates.add(order);
    } else if (type == OrderType.market) {
      _fill(order, side == OrderSide.buy ? stock.bestAsk : stock.bestBid);
    } else {
      _updates.add(order);
      _tryFillLimit(order, stock);
    }
    return order;
  }

  Order cancel(String id) {
    final order = _orders.where((o) => o.id == id).firstOrNull;
    if (order == null) {
      throw OrderRejection('not_found', 'No order "$id"', status: 404);
    }
    if (!{
      OrderStatus.open,
      OrderStatus.queued,
      OrderStatus.triggerPending,
    }.contains(order.status)) {
      throw OrderRejection(
        'not_open',
        'Order is already ${order.status.name}',
        status: 409,
      );
    }
    order
      ..version = ++_version
      ..status = OrderStatus.cancelled
      ..updatedAt = _clock();
    _updates.add(order);
    return order;
  }

  Future<void> dispose() async {
    await _tickSub.cancel();
    await _updates.close();
  }

  void _matchOpenOrders(Set<String> symbols) {
    for (final order
        in _orders
            .where(
              (o) =>
                  o.status == OrderStatus.open ||
                  o.status == OrderStatus.queued ||
                  o.status == OrderStatus.triggerPending,
            )
            .toList()) {
      if (!symbols.contains(order.symbol)) continue;
      _tryFillLimit(order, _engine[order.symbol]!);
    }
  }

  void _tryFillLimit(Order order, StockState stock) {
    if (order.status == OrderStatus.queued) {
      if (_engine.phase != MarketPhase.open) return;
      order.status = OrderStatus.open;
    }
    if (order.status == OrderStatus.triggerPending) {
      final triggered = order.side == OrderSide.buy
          ? stock.ltp >= order.triggerPrice!
          : stock.ltp <= order.triggerPrice!;
      if (!triggered) return;
      order
        ..status = OrderStatus.open
        ..version = ++_version;
      _updates.add(order);
    }
    final limit = order.limitPrice!;
    if (order.side == OrderSide.buy && stock.bestAsk <= limit) {
      _fill(order, stock.bestAsk);
    } else if (order.side == OrderSide.sell && stock.bestBid >= limit) {
      _fill(order, stock.bestBid);
    }
  }

  void _fill(Order order, double price) {
    order
      ..version = ++_version
      ..status = OrderStatus.complete
      ..averagePrice = price
      ..updatedAt = _clock();
    if (order.product == ProductType.cnc &&
        _engine[order.symbol]!.instrument.kind == InstrumentKind.equity) {
      if (order.side == OrderSide.buy) {
        _pendingDeliveries.add(
          _PendingDelivery(
            order.symbol,
            order.quantity,
            price,
            order.updatedAt,
          ),
        );
        _positions
            .putIfAbsent(
              '${order.symbol}|${order.product.name}',
              () => Position(order.symbol, product: order.product),
            )
            .apply(order.side, order.quantity, price);
        _positions['${order.symbol}|${order.product.name}']!.version =
            order.version;
      } else {
        _holdings['${order.symbol}|cnc']!.apply(
          order.side,
          order.quantity,
          price,
        );
        _holdings['${order.symbol}|cnc']!.version = order.version;
      }
    } else {
      _positions
          .putIfAbsent(
            '${order.symbol}|${order.product.name}',
            () => Position(order.symbol, product: order.product),
          )
          .apply(order.side, order.quantity, price);
      _positions['${order.symbol}|${order.product.name}']!.version =
          order.version;
    }
    _updates.add(order);
  }
}
