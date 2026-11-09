import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';

Map<String, Object?> orderJson({int version = 1, String status = 'open'}) => {
  'id': 'ORD1',
  'clientKey': 'k1',
  'version': version,
  'symbol': 'TCS',
  'product': 'mis',
  'side': 'buy',
  'type': 'limit',
  'quantity': 2,
  'lots': 1,
  'limitPrice': 3000,
  'triggerPrice': 2990,
  'averagePrice': null,
  'status': status,
  'reason': 'r',
  'message': 'm',
  'createdAt': '2026-11-10T04:00:00.000Z',
  'updatedAt': '2026-11-10T04:00:01.000Z',
};

void main() {
  test('Order.fromJson reads every field', () {
    final o = Order.fromJson(orderJson());
    expect(o.id, 'ORD1');
    expect(o.clientKey, 'k1');
    expect(o.product, ProductType.mis);
    expect(o.side, OrderSide.buy);
    expect(o.type, OrderType.limit);
    expect(o.status, OrderStatus.open);
    expect((o.quantity, o.lots), (2, 1));
    expect(
      (o.limitPrice, o.triggerPrice, o.averagePrice),
      (3000.0, 2990.0, null),
    );
    expect((o.reason, o.message), ('r', 'm'));
    expect(o.updatedAt, DateTime.utc(2026, 11, 10, 4, 0, 1));
  });

  test('Order.fromJson defaults version 0 and product cnc', () {
    final o = Order.fromJson(
      orderJson()
        ..remove('version')
        ..remove('product'),
    );
    expect(o.version, 0);
    expect(o.product, ProductType.cnc);
  });

  test('orders are equal when id, version, status, fill and time match', () {
    final a = Order.fromJson(orderJson());
    expect(a, Order.fromJson(orderJson()));
    expect(a.hashCode, Order.fromJson(orderJson()).hashCode);
    expect(a, isNot(Order.fromJson(orderJson(version: 2))));
    expect(a, isNot(Order.fromJson(orderJson(status: 'complete'))));
  });

  group('OrderRequest', () {
    const market = OrderRequest(
      symbol: 'TCS',
      side: OrderSide.sell,
      type: OrderType.market,
      product: ProductType.cnc,
      quantity: 5,
    );

    test('toJson leaves out the fields that are not set', () {
      expect(market.toJson(), {
        'symbol': 'TCS',
        'side': 'sell',
        'type': 'market',
        'product': 'cnc',
        'quantity': 5,
      });
    });

    test('toJson carries lots and prices when set', () {
      const sl = OrderRequest(
        symbol: 'NIFTY26N1024000CE',
        side: OrderSide.buy,
        type: OrderType.sl,
        product: ProductType.nrml,
        lots: 2,
        limitPrice: 101,
        triggerPrice: 100,
      );
      expect(sl.toJson(), containsPair('lots', 2));
      expect(sl.toJson(), containsPair('triggerPrice', 100.0));
      expect(sl.toJson().containsKey('quantity'), isFalse);
    });

    test('a request built at runtime equals the const one', () {
      final quantity = int.parse('5');
      final built = OrderRequest(
        symbol: 'TCS',
        side: OrderSide.sell,
        type: OrderType.market,
        product: ProductType.cnc,
        quantity: quantity,
      );
      expect(built, market);
    });

    test('equal by value', () {
      const same = OrderRequest(
        symbol: 'TCS',
        side: OrderSide.sell,
        type: OrderType.market,
        product: ProductType.cnc,
        quantity: 5,
      );
      expect(market, same);
      expect(market.hashCode, same.hashCode);
      expect(
        market,
        isNot(
          const OrderRequest(
            symbol: 'TCS',
            side: OrderSide.sell,
            type: OrderType.market,
            product: ProductType.cnc,
            quantity: 6,
          ),
        ),
      );
    });
  });

  test('place outcomes carry their details', () {
    final order = Order.fromJson(orderJson());
    final outcomes = <PlaceOutcome>[
      PlaceAcked(order),
      const PlaceRejected('price_out_of_band', 'm'),
      const PlaceTimedOut(),
    ];
    final described = [
      for (final o in outcomes)
        switch (o) {
          PlaceAcked(:final order) => order.id,
          PlaceRejected(:final code) => code,
          PlaceTimedOut() => 'timeout',
        },
    ];
    expect(described, ['ORD1', 'price_out_of_band', 'timeout']);
  });
}
