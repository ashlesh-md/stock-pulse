import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';

void main() {
  test('OrderTicketArgs: defaults, value equality, copyWith', () {
    const a = OrderTicketArgs(instrumentId: 'RELIANCE', side: OrderSide.buy);
    expect(a.source, OrderSource.manual);
    expect(a.lots, isNull);
    expect(
      a,
      const OrderTicketArgs(instrumentId: 'RELIANCE', side: OrderSide.buy),
    );
    expect(
      a.hashCode,
      const OrderTicketArgs(
        instrumentId: 'RELIANCE',
        side: OrderSide.buy,
      ).hashCode,
    );

    final b = a.copyWith(
      lots: 2,
      product: ProductType.nrml,
      limitPrice: 101.05,
      source: OrderSource.position,
    );
    expect(b.lots, 2);
    expect(b.product, ProductType.nrml);
    expect(b.limitPrice, 101.05);
    expect(b.source, OrderSource.position);
    expect(b.instrumentId, 'RELIANCE');
    expect(b == a, isFalse);
  });

  test('OrderSource covers every ticket entry point', () {
    expect(OrderSource.values.map((e) => e.name), [
      'manual',
      'watchlist',
      'chart',
      'chain',
      'ai',
      'alert',
      'deeplink',
      'position',
    ]);
  });

  test('OrderTicketArgs copyWith changes each field; toString names the instrument', () {
    const t = OrderTicketArgs(instrumentId: 'TCS', side: OrderSide.buy);
    final t2 = t.copyWith(
      instrumentId: 'INFY',
      side: OrderSide.sell,
      lots: 2,
      product: ProductType.mis,
      limitPrice: 10,
      source: OrderSource.ai,
    );
    expect(t2.instrumentId, 'INFY');
    expect(t2.lots, 2);
    expect(t2.product, ProductType.mis);
    expect(t2.limitPrice, 10);
    expect(t.copyWith(), t);
    expect(t.hashCode, t.copyWith().hashCode);
    expect(t.toString(), contains('TCS'));
  });
}
