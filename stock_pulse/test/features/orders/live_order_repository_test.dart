import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/features/orders/data/live_order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';

import '../../helpers/fake_market_socket.dart';
import 'order_domain_test.dart' show orderJson;

void main() {
  const request = OrderRequest(
    symbol: 'TCS',
    side: OrderSide.buy,
    type: OrderType.market,
    product: ProductType.cnc,
    quantity: 2,
  );
  late List<http.Request> seen;
  late FakeMarketSocket socket;

  LiveOrderRepository repo(
    Future<http.Response> Function(http.Request req) handler,
  ) {
    seen = [];
    socket = FakeMarketSocket();
    return LiveOrderRepository(
      ApiClient(
        const AppConfig(host: '127.0.0.1'),
        client: MockClient((req) {
          seen.add(req);
          return handler(req);
        }),
      ),
      socket,
    );
  }

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status);

  group('place', () {
    test('a 201 is acked with the parsed order and sends the key', () async {
      final r = repo((_) async => json({'data': orderJson()}, 201));
      final outcome = await r.place(request, idempotencyKey: 'k1');
      expect(
        outcome,
        isA<PlaceAcked>().having((o) => o.order.id, 'id', 'ORD1'),
      );
      expect(seen.single.headers['idempotency-key'], 'k1');
      expect(jsonDecode(seen.single.body), request.toJson());
    });

    test('a 4xx is rejected with the server code', () async {
      final r = repo(
        (_) async => json({
          'error': {'code': 'price_out_of_band', 'message': 'm'},
        }, 400),
      );
      expect(
        await r.place(request, idempotencyKey: 'k'),
        isA<PlaceRejected>().having((o) => o.code, 'code', 'price_out_of_band'),
      );
    });

    test('a 5xx, a timeout or a bad body is a timed out place', () async {
      expect(
        await repo((_) async => json({}, 503))
            .place(request, idempotencyKey: 'k'),
        isA<PlaceTimedOut>(),
      );
      expect(
        await repo((_) async => json({'data': 1}))
            .place(request, idempotencyKey: 'k'),
        isA<PlaceTimedOut>(),
      );
      final slow = repo(
        (_) => Future.delayed(const Duration(seconds: 1), () => json({})),
      );
      expect(
        await slow.place(
          request,
          idempotencyKey: 'k',
          timeout: const Duration(milliseconds: 10),
        ),
        isA<PlaceTimedOut>(),
      );
    });
  });

  group('getOrder', () {
    test('by id returns the order; 404 is null', () async {
      final found = await repo((_) async => json({'data': orderJson()}))
          .getOrder(id: 'ORD1');
      expect(found.valueOrNull?.id, 'ORD1');
      expect(seen.single.url.path, '/api/v1/orders/ORD1');

      final missing = await repo((_) async => json({}, 404)).getOrder(id: 'X');
      expect(missing, isA<Success<Order?>>().having((s) => s.value, 'v', null));
    });

    test('another error is passed through', () async {
      final result = await repo((_) async => json({}, 500)).getOrder(id: 'X');
      expect((result as Failure).error, isA<ServerError>());
    });

    test('by client key looks the order up by key; no data is null', () async {
      final found = await repo((_) async => json({'data': orderJson()}))
          .getOrder(clientKey: 'k');
      expect(found.valueOrNull?.id, 'ORD1');
      expect(seen.single.url.queryParameters['key'], 'k');

      final missing = await repo((_) async => json({'data': null}))
          .getOrder(clientKey: 'k');
      expect(missing, isA<Success<Order?>>().having((s) => s.value, 'v', null));
    });

    test(
      'with neither id nor client key answers null without a call',
      () async {
        final result = await repo((_) async => json({})).getOrder();
        expect(result.valueOrNull, isNull);
        expect(seen, isEmpty);
      },
    );
  });

  test('getOrders parses the list or passes the error', () async {
    final list = await repo(
      (_) async => json({
        'data': [orderJson()],
      }),
    ).getOrders();
    expect(list.valueOrNull?.single.id, 'ORD1');
    final failed = await repo((_) async => json({}, 500)).getOrders();
    expect(failed, isA<Failure<List<Order>>>());
  });

  test('cancel deletes the order and parses the answer', () async {
    final r = repo((_) async => json({'data': orderJson(status: 'cancelled')}));
    final result = await r.cancel('ORD1');
    expect(seen.single.method, 'DELETE');
    expect(result.valueOrNull?.status, OrderStatus.cancelled);
    final failed = await repo((_) async => json({}, 409)).cancel('ORD1');
    expect(failed, isA<Failure<Order>>());
  });

  test('updates are the order frames of the socket', () async {
    final r = repo((_) async => json({}));
    final next = r.updates.first;
    socket
      ..emit({'type': 'ticks', 'data': <Object?>[]})
      ..emit({'type': 'order', 'data': orderJson(version: 7)});
    expect((await next).version, 7);
    final resyncs = <void>[];
    final resyncSub = r.resyncCompleted.listen(resyncs.add);
    await r.dispose();
    expect(resyncs, isEmpty);
    await resyncSub.cancel();
  });
}
