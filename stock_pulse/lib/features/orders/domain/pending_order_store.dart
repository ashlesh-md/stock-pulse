import 'package:stock_pulse/features/orders/domain/pending_order.dart';

abstract interface class PendingOrderStore {
  Future<List<PendingOrder>> readAll();
  Future<void> put(PendingOrder order);
  Future<void> remove(String clientKey);
}
