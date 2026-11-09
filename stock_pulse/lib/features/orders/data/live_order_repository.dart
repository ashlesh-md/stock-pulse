import 'dart:async';

import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/features/orders/data/orders_api.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';

/// Orders. Commands over REST; later changes arrive as `order`
/// frames.
class LiveOrderRepository implements OrderRepository {
  LiveOrderRepository(this._api, this._socket) {
    _removeResyncReloader = _socket.registerResyncReloader(_reload);
  }

  final ApiClient _api;
  final MarketSocket _socket;
  late final void Function() _removeResyncReloader;
  final _reconciled = StreamController<Order>.broadcast(sync: true);

  /// ONE attempt: the ticket retries a [PlaceTimedOut] with the same
  /// key.
  @override
  Future<PlaceOutcome> place(
    OrderRequest req, {
    required String idempotencyKey,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final result = await _api
        .call(placeOrderEndpoint(req.toJson(), idempotencyKey: idempotencyKey))
        .timeout(timeout, onTimeout: () => const Failure(NetworkError()));
    return switch (result) {
      Failure(
        error: ServerError(:final statusCode, :final code, :final message),
      )
          when statusCode >= 400 && statusCode < 500 =>
        PlaceRejected(code, message),
      Failure() => const PlaceTimedOut(),
      Success(:final value) => switch (_order(value)) {
        Success(value: final order) => PlaceAcked(order),
        Failure() => const PlaceTimedOut(),
      },
    };
  }

  @override
  Future<Result<Order?>> getOrder({String? id, String? clientKey}) async {
    if (id == null) {
      if (clientKey == null) return const Success(null);
      final result = await _api.call(orderByKeyEndpoint(clientKey));
      return switch (result) {
        Failure(:final error) => Failure(error),
        Success(:final value) =>
          (value! as Map)['data'] == null ? const Success(null) : _order(value),
      };
    }
    final result = await _api.call(orderEndpoint(id));
    return switch (result) {
      Failure(error: ServerError(statusCode: 404)) => const Success(null),
      Failure(:final error) => Failure(error),
      Success(:final value) => _order(value),
    };
  }

  @override
  Future<Result<List<Order>>> getOrders() async {
    final result = await _api.call(ordersEndpoint);
    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final value) => parseJson(
        () => [
          for (final j in (value! as Map)['data'] as List)
            Order.fromJson(j as Map<String, Object?>),
        ],
      ),
    };
  }

  @override
  Future<Result<Order>> cancel(String id) async {
    final result = await _api.call(cancelOrderEndpoint(id));
    return switch (result) {
      Failure(:final error) => Failure(error),
      Success(:final value) => _order(value),
    };
  }

  @override
  Stream<Order> get updates => Stream.multi((controller) {
    final holder = _socket.subscribeAccount(alerts: false);
    final versions = <String, int>{};
    void emit(Order order) {
      if ((versions[order.id] ?? -1) >= order.version) return;
      versions[order.id] = order.version;
      controller.addSync(order);
    }

    final live = _socket.messages
        .where((m) => m['type'] == 'order')
        .map((m) => Order.fromJson(m['data']! as Map<String, Object?>))
        .listen(emit, onError: controller.addErrorSync);
    final recovered = _reconciled.stream.listen(emit);
    controller.onCancel = () async {
      holder.cancel();
      await live.cancel();
      await recovered.cancel();
    };
  });

  Future<void> _reload() async {
    final result = await getOrders();
    if (_reconciled.isClosed) return;
    if (result case Success(:final value)) {
      for (final order in value) {
        _reconciled.add(order);
      }
    }
  }

  @override
  Stream<void> get resyncCompleted => _socket.resyncCompleted;

  Future<void> dispose() async {
    _removeResyncReloader();
    await _reconciled.close();
  }

  Result<Order> _order(Object? value) => parseJson(
    () => Order.fromJson((value! as Map)['data'] as Map<String, Object?>),
  );
}
