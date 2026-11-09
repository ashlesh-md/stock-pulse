import 'dart:async';
import 'dart:math';

import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/features/orders/data/orders_api.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/data/account_stream.dart';
import 'package:stock_pulse/features/portfolio/data/portfolio_api.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_book.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';
import 'package:stock_pulse/features/portfolio/domain/settlement.dart';

/// Orders and positions.
///
/// Commands (place, cancel) go over REST because they need an answer: "was my
/// order accepted?". What happens LATER (a limit order filling minutes after)
/// is pushed over the WebSocket as `order` messages — see [orderUpdates].
class LivePortfolioRepository
    implements PortfolioRepository, CacheSeedablePortfolio {
  LivePortfolioRepository(this._api, this._socket, {Random? random})
    : _random = random ?? Random.secure();

  final ApiClient _api;
  final MarketSocket _socket;
  final Random _random;

  /// Holds the `orders` channel while listened to.
  @override
  Stream<Order> get orderUpdates => Stream.multi((controller) {
    var active = true;
    final versions = <String, Order>{};
    void emit(Order order) {
      if (!active) return;
      final previous = versions[order.id];
      if (previous != null && !order.updatedAt.isAfter(previous.updatedAt)) {
        return;
      }
      versions[order.id] = order;
      controller.addSync(order);
    }

    Future<void> reload() async {
      final result = await getOrders();
      if (result case Success(:final value)) {
        for (final order in value) {
          emit(order);
        }
      }
    }

    final account = _socket.subscribeAccount(alerts: false);
    final frames = _socket.messages
        .where((m) => m['type'] == 'order')
        .map((m) => Order.fromJson(m['data']! as Map<String, Object?>))
        .listen(emit, onError: controller.addErrorSync);
    final removeReloader = _socket.registerResyncReloader(reload);
    controller.onCancel = () async {
      active = false;
      account.cancel();
      removeReloader();
      await frames.cancel();
    };
  });

  @override
  Future<Result<List<Order>>> getOrders() async =>
      _list(await _api.call(ordersEndpoint), Order.fromJson);

  @override
  Future<Result<List<Position>>> getPositions() async {
    final result = _list(await _api.call(positionsEndpoint), Position.fromJson);
    if (result case Success(:final value)) {
      _current = PortfolioBook(
        positions: value,
        holdings: _current?.holdings ?? const [],
        funds: _current?.funds,
      );
    }
    return result;
  }

  PortfolioBook? _current;

  @override
  void seedFromCache(PortfolioBook book) {
    _current ??= book;
  }

  @override
  PortfolioBook? get current => _current;

  @override
  Stream<List<Position>> watchPositions() => accountStream<List<Position>>(
    socket: _socket,
    type: 'position',
    fetch: getPositions,
    parse: (json) => [Position.fromJson(json)],
    merge: (current, incoming) => [
      for (final position in current)
        if (!incoming.any((p) => p.key == position.key)) position,
      ...incoming,
    ],
  );

  @override
  Stream<List<Holding>> watchHoldings() => accountStream<List<Holding>>(
    socket: _socket,
    type: 'holding',
    fetch: getHoldings,
    parse: (json) => [Holding.fromJson(json)],
  );

  @override
  Stream<Funds> watchFunds() => accountStream<Funds>(
    socket: _socket,
    type: 'funds',
    fetch: getFunds,
    parse: Funds.fromJson,
    merge: (current, incoming) =>
        incoming.version >= current.version ? incoming : current,
    reconcileSnapshot: (current, snapshot) =>
        current.version > snapshot.version ? current : snapshot,
  );

  @override
  Stream<Settlement> get settlements => _socket.messages
      .where((m) => m['type'] == 'settlement')
      .map((m) => Settlement.fromJson(m['data']! as Map<String, Object?>));

  @override
  Future<Result<List<Holding>>> getHoldings() async {
    final result = _list(await _api.call(holdingsEndpoint), Holding.fromJson);
    if (result case Success(:final value)) {
      _current = PortfolioBook(
        positions: _current?.positions ?? const [],
        holdings: value,
        funds: _current?.funds,
      );
    }
    return result;
  }

  @override
  Future<Result<Funds>> getFunds() async {
    final response = await _api.call(fundsEndpoint);
    final result = switch (response) {
      Failure(:final error) => Failure<Funds>(error),
      Success(:final value) => parseJson(
        () => Funds.fromJson((value! as Map)['data'] as Map<String, Object?>),
      ),
    };
    if (result case Success(:final value)) {
      _current = PortfolioBook(
        positions: _current?.positions ?? const [],
        holdings: _current?.holdings ?? const [],
        funds: value,
      );
    }
    return result;
  }

  /// Places an order, retrying ONCE if the network failed.
  ///
  /// A timeout does not tell us whether the server got the order. Retrying
  /// blindly could buy twice, so both attempts send the same
  /// `Idempotency-Key`: the server returns the first order instead of
  /// creating a second.
  @override
  Future<Result<Order>> placeOrder({
    required String symbol,
    required OrderSide side,
    required OrderType type,
    required int quantity,
    double? limitPrice,
    String? idempotencyKey,
    ProductType product = ProductType.cnc,
    int? lots,
    double? triggerPrice,
  }) async {
    final key = idempotencyKey ?? _newKey();
    final body = {
      'symbol': symbol,
      'side': side.name,
      'type': type.name,
      'quantity': quantity,
      'product': product.name,
      'lots': ?lots,
      'triggerPrice': ?triggerPrice,
      'limitPrice': ?limitPrice,
    };
    final endpoint = placeOrderEndpoint(body, idempotencyKey: key);
    var result = await _api.call(endpoint);
    if (result case Failure(error: NetworkError())) {
      result = await _api.call(endpoint);
    }
    return _one(result);
  }

  @override
  Future<Result<Order>> cancelOrder(String id) async =>
      _one(await _api.call(cancelOrderEndpoint(id)));

  String _newKey() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  Result<Order> _one(Result<Object?> result) => switch (result) {
    Failure(:final error) => Failure(error),
    Success(:final value) => parseJson(
      () => Order.fromJson((value! as Map)['data'] as Map<String, Object?>),
    ),
  };

  Result<List<T>> _list<T>(
    Result<Object?> result,
    T Function(Map<String, Object?>) parse,
  ) => switch (result) {
    Failure(:final error) => Failure(error),
    Success(:final value) => parseJson(
      () => [
        for (final j in (value! as Map)['data'] as List)
          parse(j as Map<String, Object?>),
      ],
    ),
  };
}
