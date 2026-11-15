import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/pending_order.dart';
import 'package:stock_pulse/features/orders/domain/pending_order_store.dart';

Override fakePendingOrderStoreOverride() => pendingOrderStoreProvider
    .overrideWith((ref) async => FakePendingOrderStore());

class FakePendingOrderStore implements PendingOrderStore {
  final orders = <String, PendingOrder>{};
  bool failWrites = false;

  @override
  Future<List<PendingOrder>> readAll() async => orders.values.toList();

  @override
  Future<void> put(PendingOrder order) async {
    if (failWrites) throw StateError('disk full');
    orders[order.clientKey] = order;
  }

  @override
  Future<void> remove(String clientKey) async {
    orders.remove(clientKey);
  }
}
