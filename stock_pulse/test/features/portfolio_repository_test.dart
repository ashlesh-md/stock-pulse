import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/data/live_portfolio_repository.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

import '../helpers/fake_market_socket.dart';

const _order = {
  'id': 'ORD000001',
  'symbol': 'TCS',
  'side': 'buy',
  'type': 'market',
  'quantity': 2,
  'status': 'complete',
  'averagePrice': 3000.0,
  'limitPrice': null,
  'message': null,
  'createdAt': '2026-11-04T05:00:00.000Z',
  'updatedAt': '2026-11-04T05:00:00.000Z',
};

void main() {
  const config = AppConfig(host: 'localhost');
  late MarketSocket socket;
  setUp(() => socket = MarketSocket(config.socketUri));
  tearDown(() => socket.dispose());

  Future<Result<Order>> place(PortfolioRepository repo) => repo.placeOrder(
    symbol: 'TCS',
    side: OrderSide.buy,
    type: OrderType.market,
    quantity: 2,
  );

  test(
    'a network failure is retried once with the SAME idempotency key',
    () async {
      final keys = <String?>[];
      final client = MockClient((req) async {
        keys.add(req.headers['idempotency-key']);
        if (keys.length == 1) throw http.ClientException('connection reset');
        return http.Response(jsonEncode({'data': _order}), 201);
      });
      final result = await place(
        LivePortfolioRepository(ApiClient(config, client: client), socket),
      );

      expect(result, isA<Success<Order>>());
      expect(keys, hasLength(2));
      expect(keys.first, isNotNull);
      expect(keys.first, keys.last);
    },
  );

  test('a server rejection (4xx) is NOT retried', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      // bytes(): a UTF-8 body with no charset, like many real servers send.
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'error': {
              'code': 'invalid_quantity',
              'message': 'Quantity must be 1–10000',
            },
          }),
        ),
        400,
      );
    });
    final result = await place(
      LivePortfolioRepository(ApiClient(config, client: client), socket),
    );

    expect(calls, 1);
    expect(
      result,
      isA<Failure<Order>>().having(
        (e) => e.error,
        'error',
        isA<ServerError>().having(
          (f) => f.message,
          'message',
          'Quantity must be 1–10000', // decoded as UTF-8, not garbled
        ),
      ),
    );
  });

  test('each order gets a new key', () async {
    final keys = <String?>{};
    final client = MockClient((req) async {
      keys.add(req.headers['idempotency-key']);
      return http.Response(jsonEncode({'data': _order}), 201);
    });
    final repo = LivePortfolioRepository(
      ApiClient(config, client: client),
      socket,
    );
    await place(repo);
    await place(repo);
    expect(keys, hasLength(2));
  });

  test(
    'orderUpdates holds the orders channel only while listened to',
    () async {
      final fake = FakeMarketSocket();
      final repo = LivePortfolioRepository(
        ApiClient(
          config,
          client: MockClient((_) async => http.Response('', 500)),
        ),
        fake,
      );

      final sub = repo.orderUpdates.listen((_) {});
      final holder = fake.accountSubs.single;
      expect((holder.orders, holder.alerts), (true, false));

      await sub.cancel();
      expect(holder.isCancelled, isTrue);
    },
  );

  test('an order frame arrives as an Order', () async {
    final fake = FakeMarketSocket();
    final repo = LivePortfolioRepository(
      ApiClient(
        config,
        client: MockClient((_) async => http.Response('', 500)),
      ),
      fake,
    );
    final updates = <Order>[];
    final sub = repo.orderUpdates.listen(updates.add);

    fake.emit({'type': 'order', 'data': _order});
    await pumpEventQueue();

    expect(updates.single.id, 'ORD000001');
    await sub.cancel();
  });
}
