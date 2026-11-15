import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/orders/application/order_ticket_state.dart';
import 'package:stock_pulse/features/orders/di/order_preflight_provider.dart';
import 'package:stock_pulse/features/orders/di/order_ticket_providers.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';

import '../../helpers/fake_pending_order_store.dart';

const _timeouts = [PlaceTimedOut(), PlaceTimedOut(), PlaceTimedOut()];

void main() {
  late FakePendingOrderStore store;
  late _Repository repo;
  late ProviderContainer container;
  final provider = orderTicketControllerProvider('TCS');

  setUp(() {
    store = FakePendingOrderStore();
    repo = _Repository(_timeouts);
    container = ProviderContainer.test(
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
        orderRepositoryProvider.overrideWithValue(repo),
        pendingOrderStoreProvider.overrideWith((ref) async => store),
      ],
    );
  });

  Future<String?> buy(int quantity) => container
      .read(provider.notifier)
      .submit(side: OrderSide.buy, type: OrderType.market, quantity: quantity);

  test('FR-31 once the server knows the uncertain order, the same tap reports '
      'it and never sends it again', () async {
    await buy(2);
    expect(container.read(provider).uncertain, isTrue);

    repo.known = true;
    expect(await buy(2), isNull);

    expect(repo.keys, hasLength(3));
    expect(container.read(provider).uncertain, isFalse);
    expect(store.orders, isEmpty);
  });

  test('FR-31 once the server knows the uncertain order, a different order '
      'can be placed with a new key', () async {
    await buy(2);
    final firstKey = repo.keys.first;
    repo
      ..known = true
      ..outcomes.add(PlaceAcked(_order('other')));

    expect(await buy(5), isNull);

    expect(repo.keys, hasLength(4));
    expect(repo.keys.last, isNot(firstKey));
    expect(container.read(provider).uncertain, isFalse);
  });

  test('FR-31 while the server still does not know it, the ticket stays '
      'blocked', () async {
    await buy(2);
    expect(await buy(5), isNotNull);
    expect(repo.keys, hasLength(3));
    expect(container.read(provider).uncertain, isTrue);
  });

  test('F11 a failed write before sending leaves the ticket free, not stuck '
      'or waiting on an order that never existed', () async {
    store.failWrites = true;

    expect(await buy(2), isNotNull);
    expect(repo.keys, isEmpty);
    expect(container.read(provider), const OrderTicketState());

    store.failWrites = false;
    repo.outcomes
      ..clear()
      ..add(PlaceAcked(_order('next')));
    expect(await buy(2), isNull);
    expect(repo.keys, hasLength(1));
  });

  test(
    'F11 a failure after sending keeps the key and waits on the server',
    () async {
      repo.throwOnPlace = true;

      expect(await buy(2), isNotNull);

      expect(container.read(provider).uncertain, isTrue);
      expect(store.orders, hasLength(1));
    },
  );

  test('F11 a failed lookup of the uncertain order leaves the ticket free to '
      'try again', () async {
    await buy(2);
    repo.failLookup = true;

    expect(await buy(2), isNotNull);

    final state = container.read(provider);
    expect((state.submitting, state.uncertain), (false, true));
  });

  test(
    'FR-31 a second tap while the server is being asked is refused',
    () async {
      await buy(2);
      repo.known = true;

      final first = buy(2);
      final second = await buy(2);

      expect(second, isNotNull);
      expect(await first, isNull);
      expect(repo.keys, hasLength(3));
    },
  );
}

Order _order(String key) => Order(
  id: 'order-$key',
  clientKey: key,
  symbol: 'TCS',
  side: OrderSide.buy,
  type: OrderType.market,
  quantity: 2,
  status: OrderStatus.complete,
  createdAt: DateTime.utc(2026, 11, 16),
  updatedAt: DateTime.utc(2026, 11, 16),
);

class _Repository implements OrderRepository {
  _Repository(List<PlaceOutcome> outcomes) : outcomes = Queue.of(outcomes);

  final Queue<PlaceOutcome> outcomes;
  final keys = <String>[];
  bool known = false;
  bool throwOnPlace = false;
  bool failLookup = false;

  @override
  Future<PlaceOutcome> place(
    OrderRequest req, {
    required String idempotencyKey,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    keys.add(idempotencyKey);
    if (throwOnPlace) throw StateError('socket closed mid-request');
    return outcomes.removeFirst();
  }

  @override
  Future<Result<Order?>> getOrder({String? id, String? clientKey}) async {
    if (failLookup) throw StateError('lookup failed');
    return Success(known && clientKey != null ? _order(clientKey) : null);
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
