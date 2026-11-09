import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';

/// Orders. Commands over REST; later changes arrive as `order`
/// frames.
abstract interface class OrderRepository {
  /// One attempt: the ticket retries a [PlaceTimedOut] with the same key.
  Future<PlaceOutcome> place(
    OrderRequest req, {
    required String idempotencyKey,
    Duration timeout = const Duration(seconds: 5),
  });

  /// Null when the server has no such order.
  Future<Result<Order?>> getOrder({String? id, String? clientKey});

  Future<Result<List<Order>>> getOrders();

  Future<Result<Order>> cancel(String id);

  Stream<Order> get updates;

  Stream<void> get resyncCompleted;
}
