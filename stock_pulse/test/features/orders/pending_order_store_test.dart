import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/orders/data/local_pending_order_store.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/pending_order.dart';

import '../../helpers/fake_local_prefs.dart';

void main() {
  test(
    'pending order survives a prefs restart and removes by client key',
    () async {
      final prefs = FakeLocalPrefs();
      final order = PendingOrder(
        clientKey: 'key-1',
        request: const OrderRequest(
          symbol: 'TCS',
          side: OrderSide.buy,
          type: OrderType.limit,
          product: ProductType.cnc,
          quantity: 3,
          limitPrice: 3500,
        ),
        createdAt: DateTime.utc(2026, 11, 9, 6),
      );
      await LocalPendingOrderStore(prefs).put(order);

      final restored = await LocalPendingOrderStore(prefs).readAll();
      expect(restored, [order]);
      expect(restored.single.toOrder().status, OrderStatus.pending);
      expect(restored.single.toOrder().clientKey, 'key-1');
      await LocalPendingOrderStore(prefs).remove('key-1');
      expect(await LocalPendingOrderStore(prefs).readAll(), isEmpty);
    },
  );

  test('put keeps other keys and replaces the same key', () async {
    final prefs = FakeLocalPrefs();
    final store = LocalPendingOrderStore(prefs);
    final first = _order('key-1', 3);
    final second = _order('key-2', 4);
    await store.put(first);
    await store.put(second);
    final replaced = _order('key-1', 5);
    await store.put(replaced);

    final restored = await store.readAll();
    expect(restored, unorderedEquals([second, replaced]));
    expect(restored.toSet(), hasLength(2));
    expect(replaced, isNot(first));
    expect(replaced.hashCode, isNot(first.hashCode));
    expect(_order('key-1', 3).hashCode, first.hashCode);
  });
}

PendingOrder _order(String key, int quantity) => PendingOrder(
  clientKey: key,
  request: OrderRequest(
    symbol: 'TCS',
    side: OrderSide.buy,
    type: OrderType.limit,
    product: ProductType.cnc,
    quantity: quantity,
    limitPrice: 3500,
  ),
  createdAt: DateTime.utc(2026, 11, 9, 6),
);
