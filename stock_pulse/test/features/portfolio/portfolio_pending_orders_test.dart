import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/pending_order.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

import '../../helpers/fake_pending_order_store.dart';

class _Portfolio extends Mock implements PortfolioRepository {}

class _Market extends Mock implements MarketRepository {}

class _Orders implements OrderRepository {
  Order? result;
  final lookupKeys = <String?>[];

  @override
  Future<Result<Order?>> getOrder({String? id, String? clientKey}) async {
    lookupKeys.add(clientKey);
    return Success(result);
  }

  @override
  Future<PlaceOutcome> place(
    OrderRequest req, {
    required String idempotencyKey,
    Duration timeout = const Duration(seconds: 5),
  }) async => const PlaceTimedOut();

  @override
  Future<Result<List<Order>>> getOrders() async => const Success([]);

  @override
  Future<Result<Order>> cancel(String id) async =>
      const Failure(NetworkError());

  @override
  Stream<Order> get updates => const Stream.empty();

  @override
  Stream<void> get resyncCompleted => const Stream.empty();
}

void main() {
  late _Portfolio portfolio;
  late _Market market;
  late _Orders orders;
  late FakePendingOrderStore pendingStore;
  late ProviderContainer container;

  setUp(() {
    portfolio = _Portfolio();
    market = _Market();
    orders = _Orders();
    pendingStore = FakePendingOrderStore();
    when(() => portfolio.orderUpdates).thenAnswer((_) => const Stream.empty());
    when(() => portfolio.getOrders())
        .thenAnswer((_) async => const Success([]));
    when(() => portfolio.getPositions())
        .thenAnswer((_) async => const Success([]));
    when(() => portfolio.current).thenReturn(null);
    when(() => market.latestQuotes(any())).thenReturn(const []);
    container = ProviderContainer.test(
      overrides: [
        portfolioRepositoryProvider.overrideWithValue(portfolio),
        marketRepositoryProvider.overrideWithValue(market),
        orderRepositoryProvider.overrideWithValue(orders),
        pendingOrderStoreProvider.overrideWith((ref) async => pendingStore),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test(
    'restores unresolved requests as Pending without resubmitting',
    () async {
      await pendingStore.put(_pending());
      container.listen(portfolioControllerProvider, (_, _) {});
      final state = await container.read(portfolioControllerProvider.future);

      expect(state.orders.single.status, OrderStatus.pending);
      expect(state.orders.single.clientKey, 'client-key');
      expect(orders.lookupKeys, isEmpty);
    },
  );

  test(
    'Refresh status replaces the Pending row when the server has it',
    () async {
      await pendingStore.put(_pending());
      container.listen(portfolioControllerProvider, (_, _) {});
      final controller = container.read(portfolioControllerProvider.notifier);
      final pending = (await container.read(portfolioControllerProvider.future))
          .orders
          .single;
      orders.result = _serverOrder(OrderStatus.open);

      await controller.refreshPendingStatus(pending);

      final state = container.read(portfolioControllerProvider).requireValue;
      expect(orders.lookupKeys, ['client-key']);
      expect(state.orders, [_serverOrder(OrderStatus.open)]);
      expect(await pendingStore.readAll(), isEmpty);
    },
  );

  test('a pending row the server already has is dropped on load', () async {
    await pendingStore.put(_pending());
    when(() => portfolio.getOrders())
        .thenAnswer((_) async => Success([_serverOrder(OrderStatus.open)]));
    container.listen(portfolioControllerProvider, (_, _) {});

    final state = await container.read(portfolioControllerProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(state.orders, [_serverOrder(OrderStatus.open)]);
    expect(await pendingStore.readAll(), isEmpty);
  });

  test('a live resync outcome replaces Pending by client key', () async {
    final updates = StreamController<Order>.broadcast(sync: true);
    when(() => portfolio.orderUpdates).thenAnswer((_) => updates.stream);
    await pendingStore.put(_pending());
    container.listen(portfolioControllerProvider, (_, _) {});
    await container.read(portfolioControllerProvider.future);

    updates.add(_serverOrder(OrderStatus.complete));
    await Future<void>.delayed(Duration.zero);

    final state = container.read(portfolioControllerProvider).requireValue;
    expect(state.orders, [_serverOrder(OrderStatus.complete)]);
    expect(await pendingStore.readAll(), isEmpty);
    await updates.close();
  });
}

PendingOrder _pending() => PendingOrder(
  clientKey: 'client-key',
  request: const OrderRequest(
    symbol: 'TCS',
    side: OrderSide.buy,
    type: OrderType.market,
    product: ProductType.cnc,
    quantity: 2,
  ),
  createdAt: DateTime.utc(2026, 11, 9, 6),
);

Order _serverOrder(OrderStatus status) => Order(
  id: 'order-1',
  clientKey: 'client-key',
  symbol: 'TCS',
  side: OrderSide.buy,
  type: OrderType.market,
  quantity: 2,
  status: status,
  createdAt: DateTime.utc(2026, 11, 9, 6),
  updatedAt: DateTime.utc(2026, 11, 9, 6),
);
