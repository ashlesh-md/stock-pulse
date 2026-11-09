import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/orders/di/order_preflight_provider.dart';
import 'package:stock_pulse/features/orders/di/order_ticket_providers.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';

import '../../helpers/fake_pending_order_store.dart';

void main() {
  late FakePendingOrderStore pendingStore;
  setUp(() => pendingStore = FakePendingOrderStore());

  test(
    'a second tap while submitting never makes another place call',
    () async {
      final repo = _Repository();
      final ack = Completer<PlaceOutcome>();
      repo.onPlace = (_) => ack.future;
      final container = _container(repo, pendingStore: pendingStore);
      final controller = container.read(
        orderTicketControllerProvider('TCS').notifier,
      );

      final first = controller.submit(
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 2,
      );
      await Future<void>.delayed(Duration.zero);
      final duplicate = await controller.submit(
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 2,
      );
      expect(duplicate, isNotNull);
      expect(repo.keys, hasLength(1));
      ack.complete(PlaceAcked(_order()));
      expect(await first, isNull);
      expect(repo.keys, hasLength(1));
      container.dispose();
    },
  );

  test('a client-key match after timeout prevents another POST', () async {
    final repo = _Repository(outcomes: [const PlaceTimedOut()]);
    repo.matchLookupKey = true;
    final container = _container(repo, pendingStore: pendingStore);
    final result = await container
        .read(orderTicketControllerProvider('TCS').notifier)
        .submit(side: OrderSide.buy, type: OrderType.market, quantity: 2);

    expect(result, isNull);
    expect(repo.keys, hasLength(1));
    expect(repo.lookupKeys, [repo.keys.single]);
    container.dispose();
  });

  test('a client-key mismatch is not treated as an accepted order', () async {
    final repo = _Repository(
      outcomes: [
        const PlaceTimedOut(),
        const PlaceTimedOut(),
        const PlaceTimedOut(),
      ],
    )..lookupOrder = _order();
    final container = _container(repo, pendingStore: pendingStore);

    await container
        .read(orderTicketControllerProvider('TCS').notifier)
        .submit(side: OrderSide.buy, type: OrderType.market, quantity: 2);

    expect(repo.keys, hasLength(3));
    expect(pendingStore.orders, hasLength(1));
    container.dispose();
  });

  test(
    'three unknown attempts use one key and leave the ticket pending',
    () async {
      final repo = _Repository(
        outcomes: [
          const PlaceTimedOut(),
          const PlaceTimedOut(),
          const PlaceTimedOut(),
        ],
      );
      final container = _container(repo, pendingStore: pendingStore);
      final provider = orderTicketControllerProvider('TCS');
      final controller = container.read(provider.notifier);

      expect(
        await controller.submit(
          side: OrderSide.buy,
          type: OrderType.market,
          quantity: 2,
        ),
        isNull,
      );
      expect(repo.keys, hasLength(3));
      expect(repo.keys.toSet(), hasLength(1));
      expect(repo.lookupKeys, everyElement(repo.keys.first));
      expect(container.read(provider).uncertain, isTrue);
      expect(pendingStore.orders, hasLength(1));
      expect(
        await controller.submit(
          side: OrderSide.buy,
          type: OrderType.market,
          quantity: 2,
        ),
        isNotNull,
      );
      expect(repo.keys, hasLength(3));
      container.dispose();
    },
  );

  test(
    'after a rebuild an unsent changed draft still waits on the pending one',
    () async {
      final repo = _Repository(
        outcomes: [
          const PlaceTimedOut(),
          const PlaceTimedOut(),
          const PlaceTimedOut(),
        ],
      );
      final container = _container(repo, pendingStore: pendingStore);
      final provider = orderTicketControllerProvider('TCS');
      final controller = container.read(provider.notifier);
      await controller.submit(
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 2,
      );
      container.invalidate(provider);
      expect(container.read(provider).uncertain, isFalse);

      final changed = await container
          .read(provider.notifier)
          .submit(side: OrderSide.buy, type: OrderType.market, quantity: 5);

      expect(changed, isNotNull);
      expect(repo.keys, hasLength(3));
      container.dispose();
    },
  );

  test('submission changes to checking status after three seconds', () async {
    final repo = _Repository();
    final response = Completer<PlaceOutcome>();
    repo.onPlace = (_) => response.future;
    final container = _container(repo, pendingStore: pendingStore);
    final provider = orderTicketControllerProvider('TCS');
    final controller = container.read(provider.notifier);
    final submission = controller.submit(
      side: OrderSide.buy,
      type: OrderType.market,
      quantity: 2,
    );

    await Future<void>.delayed(const Duration(milliseconds: 3100));
    expect(container.read(provider).checkingStatus, isTrue);
    response.complete(PlaceAcked(_order()));
    expect(await submission, isNull);
    container.dispose();
  });
}

ProviderContainer _container(
  OrderRepository repository, {
  required FakePendingOrderStore pendingStore,
}) => ProviderContainer.test(
  overrides: [
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
    orderRepositoryProvider.overrideWithValue(repository),
    pendingOrderStoreProvider.overrideWith((ref) async => pendingStore),
  ],
);

Order _order({String? clientKey = 'key'}) => Order(
  id: 'order-1',
  clientKey: clientKey,
  symbol: 'TCS',
  side: OrderSide.buy,
  type: OrderType.market,
  quantity: 2,
  status: OrderStatus.open,
  createdAt: DateTime.utc(2026, 11, 9),
  updatedAt: DateTime.utc(2026, 11, 9),
);

class _Repository implements OrderRepository {
  _Repository({List<PlaceOutcome> outcomes = const []})
    : _outcomes = Queue.of(outcomes);

  final Queue<PlaceOutcome> _outcomes;
  final keys = <String>[];
  final lookupKeys = <String?>[];
  Future<PlaceOutcome> Function(OrderRequest request)? onPlace;
  Order? lookupOrder;
  bool matchLookupKey = false;

  @override
  Future<PlaceOutcome> place(
    OrderRequest req, {
    required String idempotencyKey,
    Duration timeout = const Duration(seconds: 5),
  }) {
    keys.add(idempotencyKey);
    return onPlace?.call(req) ?? Future.value(_outcomes.removeFirst());
  }

  @override
  Future<Result<Order?>> getOrder({String? id, String? clientKey}) async {
    lookupKeys.add(clientKey);
    return Success(
      matchLookupKey && clientKey != null
          ? _order(clientKey: clientKey)
          : lookupOrder,
    );
  }

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
