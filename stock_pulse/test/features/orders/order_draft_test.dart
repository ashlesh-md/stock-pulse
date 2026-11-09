import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/orders/application/order_draft.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';

OrderDraft _draft({
  OrderSide side = OrderSide.buy,
  double? limit,
  int? lots,
  ProductType? product,
  int lotSize = 1,
}) => OrderDraft.fromSeed((
  args: OrderTicketArgs(
    instrumentId: 'TCS',
    side: side,
    lots: lots,
    limitPrice: limit,
    product: product,
  ),
  lotSize: lotSize,
  tickSize: .05,
  ltp: 100,
));

void main() {
  test('a seed without a limit is a market order of one unit', () {
    final d = _draft();
    expect(d.type, OrderType.market);
    expect(d.product, ProductType.cnc);
    expect(d.quantity, 1);
    expect(d.lots, isNull);
    expect(d.sentLimit, isNull);
    expect(d.estimatedPrice, 100);
    expect(d.issues, isEmpty);
  });

  test('a lot-size contract counts lots and defaults to NRML', () {
    final d = _draft(lotSize: 75, lots: 2);
    expect(d.inLots, isTrue);
    expect(d.quantity, 150);
    expect(d.lots, 2);
    expect(d.product, ProductType.nrml);
    expect(d.orderValue, 15000);
  });

  test('a seed limit opens a limit order at that price', () {
    final d = _draft(limit: 99.5, product: ProductType.mis);
    expect(d.type, OrderType.limit);
    expect(d.sentLimit, 99.5);
    expect(d.product, ProductType.mis);
  });

  test('quantity must be 1 to 10,000', () {
    expect(_draft().copyWith(count: () => null).issues, {DraftIssue.quantity});
    expect(_draft().copyWith(count: () => 0).issues, {DraftIssue.quantity});
    expect(_draft().copyWith(count: () => OrderDraft.maxCount + 1).issues, {
      DraftIssue.quantity,
    });
    expect(_draft().copyWith(count: () => OrderDraft.maxCount).issues, isEmpty);
  });

  test('a limit price must be positive and on the tick', () {
    final limit = _draft(limit: 100);
    expect(limit.copyWith(limitPrice: () => 100.03).issues, {DraftIssue.price});
    expect(limit.copyWith(limitPrice: () => 0).issues, {DraftIssue.price});
    expect(limit.copyWith(limitPrice: () => null).issues, {DraftIssue.price});
    expect(limit.copyWith(limitPrice: () => double.nan).issues, {
      DraftIssue.price,
    });
    expect(limit.copyWith(limitPrice: () => 100.05).issues, isEmpty);
  });

  test('a buy trigger sits at or below the limit, a sell one at or above', () {
    final buy = _draft().copyWith(type: OrderType.sl, limitPrice: () => 100);
    expect(buy.copyWith(triggerPrice: () => 99).issues, isEmpty);
    expect(buy.copyWith(triggerPrice: () => 101).issues, {DraftIssue.trigger});
    expect(buy.copyWith(triggerPrice: () => null).issues, {DraftIssue.trigger});
    final sell = buy.copyWith(side: OrderSide.sell);
    expect(sell.copyWith(triggerPrice: () => 101).issues, isEmpty);
    expect(sell.copyWith(triggerPrice: () => 99).issues, {DraftIssue.trigger});
    expect(
      sell.copyWith(limitPrice: () => null, triggerPrice: () => 99).issues,
      {DraftIssue.price, DraftIssue.trigger},
    );
    expect(sell.copyWith(triggerPrice: () => 101).sentTrigger, 101);
  });

  test('equal drafts are equal; any field change is not', () {
    expect(_draft(), _draft());
    expect(_draft().hashCode, _draft().hashCode);
    expect(_draft().copyWith(submitting: true), isNot(_draft()));
    expect(_draft().copyWith(error: () => 'x').error, 'x');
    expect(_draft().copyWith(product: ProductType.mis), isNot(_draft()));
  });
}
