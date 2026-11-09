import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/orders/application/order_draft.dart';
import 'package:stock_pulse/features/orders/application/order_draft_controller.dart';
import 'package:stock_pulse/features/orders/di/order_preflight_provider.dart';
import 'package:stock_pulse/features/orders/di/order_ticket_providers.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';

import '../../helpers/fake_crash_reporter.dart';
import '../../helpers/fake_pending_order_store.dart';

class _Orders extends Mock implements OrderRepository {}

const OrderDraftSeed _seed = (
  args: OrderTicketArgs(instrumentId: 'TCS', side: OrderSide.buy),
  lotSize: 1,
  tickSize: .05,
  ltp: 3000,
);

void main() {
  late _Orders orders;
  late FakePendingOrderStore pendingOrders;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(
      const OrderRequest(
        symbol: 'TCS',
        side: OrderSide.buy,
        type: OrderType.market,
        product: ProductType.cnc,
        quantity: 1,
      ),
    );
  });

  void answer(PlaceOutcome result) => when(
    () => orders.place(any(), idempotencyKey: any(named: 'idempotencyKey')),
  ).thenAnswer((_) async => result);

  setUp(() {
    orders = _Orders();
    pendingOrders = FakePendingOrderStore();
    container = ProviderContainer.test(
      overrides: [
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        orderRepositoryProvider.overrideWithValue(orders),
        pendingOrderStoreProvider.overrideWith((ref) async => pendingOrders),
        orderPreflightProvider.overrideWithValue(
          ({
            required symbol,
            required side,
            required type,
            required product,
            required quantity,
            lots,
            limitPrice,
            triggerPrice,
          }) => null,
        ),
      ],
    );
  });

  OrderDraftController controller() {
    container.listen(orderDraftControllerProvider(_seed), (_, _) {});
    return container.read(orderDraftControllerProvider(_seed).notifier);
  }

  OrderDraft draft() => container.read(orderDraftControllerProvider(_seed));

  test('setters edit the draft', () {
    controller()
      ..setSide(OrderSide.sell)
      ..setType(OrderType.sl)
      ..setProduct(ProductType.mis)
      ..setCount(5)
      ..setLimitPrice(2990)
      ..setTriggerPrice(2995);
    expect(draft().side, OrderSide.sell);
    expect(draft().type, OrderType.sl);
    expect(draft().product, ProductType.mis);
    expect(draft().quantity, 5);
    expect(draft().sentLimit, 2990);
    expect(draft().sentTrigger, 2995);
  });

  test('an invalid draft is not sent', () async {
    final c = controller()..setCount(0);
    expect(await c.place(), isFalse);
    verifyNever(
      () => orders.place(any(), idempotencyKey: any(named: 'idempotencyKey')),
    );
  });

  test(
    'insufficient funds rejection stays inline and is not duplicated',
    () async {
      answer(const PlaceRejected('insufficient_funds', ''));
      final c = controller();
      expect(await c.place(), isFalse);
      expect(draft().submitting, isFalse);
      expect(draft().error, contains('funds'));
      c.setCount(2);
      expect(draft().error, isNull);
      verify(
        () => orders.place(any(), idempotencyKey: any(named: 'idempotencyKey')),
      ).called(1);
    },
  );

  test('edits are ignored while the order is being placed', () async {
    final response = Completer<PlaceOutcome>();
    when(
      () => orders.place(any(), idempotencyKey: any(named: 'idempotencyKey')),
    ).thenAnswer((_) => response.future);
    final c = controller();
    final placing = c.place();
    expect(draft().submitting, isTrue);
    c.setCount(9);
    expect(await c.place(), isFalse);
    response.complete(PlaceAcked(_order()));
    expect(await placing, isTrue);
    expect(draft().quantity, 1);
  });
}

Order _order() => Order(
  id: 'order-1',
  symbol: 'TCS',
  side: OrderSide.buy,
  type: OrderType.market,
  quantity: 1,
  status: OrderStatus.open,
  createdAt: DateTime.utc(2026, 11, 9),
  updatedAt: DateTime.utc(2026, 11, 9),
);
