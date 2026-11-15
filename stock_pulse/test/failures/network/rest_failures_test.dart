import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/domain/endpoint.dart';
import 'package:stock_pulse/features/orders/data/live_order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';

import '../../helpers/fake_market_socket.dart';

const _request = OrderRequest(
  symbol: 'TCS',
  side: OrderSide.buy,
  type: OrderType.market,
  product: ProductType.cnc,
  quantity: 2,
);

Map<String, Object?> _order(String key) => {
  'id': 'ORD7',
  'clientKey': key,
  'version': 1,
  'symbol': 'TCS',
  'product': 'cnc',
  'side': 'buy',
  'type': 'market',
  'quantity': 2,
  'lots': null,
  'limitPrice': null,
  'triggerPrice': null,
  'averagePrice': 3000.5,
  'status': 'complete',
  'reason': null,
  'message': null,
  'createdAt': '2026-11-10T04:00:00.000Z',
  'updatedAt': '2026-11-10T04:00:01.000Z',
};

void main() {
  ApiClient api(
    Future<http.Response> Function(http.Request request) handler, {
    List<Duration>? waits,
  }) {
    final client = ApiClient(
      const AppConfig(host: '127.0.0.1'),
      client: MockClient(handler),
      wait: (delay) async => waits?.add(delay),
    );
    addTearDown(client.close);
    return client;
  }

  for (final status in [500, 502, 504]) {
    test('F5 a $status read retries once after one second, then fails with '
        'a ServerError', () async {
      var calls = 0;
      final waits = <Duration>[];
      final client = api((_) async {
        calls++;
        return http.Response('{"error":{"code":"down","message":"x"}}', status);
      }, waits: waits);

      final result = await client.call(const Endpoint.get('/api/v1/quotes'));

      expect(calls, 2);
      expect(waits, [const Duration(seconds: 1)]);
      expect(
        result,
        isA<Failure<Object?>>().having(
          (f) => f.error,
          'error',
          isA<ServerError>().having((e) => e.statusCode, 'status', status),
        ),
      );
    });
  }

  test('F5 a 500 read that recovers on the retry succeeds', () async {
    var calls = 0;
    final client = api(
      (_) async => ++calls == 1
          ? http.Response('', 500)
          : http.Response('{"data":[]}', 200),
    );

    final result = await client.call(const Endpoint.get('/api/v1/quotes'));

    expect(result.valueOrNull, {'data': <Object?>[]});
  });

  test('F2 with the network down a read fails fast with a NetworkError after '
      'its one retry', () async {
    var calls = 0;
    final client = api((_) async {
      calls++;
      throw http.ClientException('network is unreachable');
    });

    final result = await client.call(const Endpoint.get('/api/v1/quotes'));

    expect(calls, 2);
    expect(
      result,
      isA<Failure<Object?>>().having((f) => f.error, 'e', isA<NetworkError>()),
    );
  });

  group('F4 order POST', () {
    late List<http.Request> seen;

    LiveOrderRepository repository(
      http.Response Function(http.Request request) handler,
    ) {
      seen = [];
      return LiveOrderRepository(
        api((request) async {
          seen.add(request);
          return handler(request);
        }),
        FakeMarketSocket(),
      );
    }

    test('a 409 duplicate key is treated as the original order', () async {
      final repo = repository(
        (request) => request.method == 'POST'
            ? http.Response(
                '{"error":{"code":"duplicate_key","message":"exists"}}',
                409,
              )
            : http.Response(jsonEncode({'data': _order('k9')}), 200),
      );

      final outcome = await repo.place(_request, idempotencyKey: 'k9');

      expect(
        outcome,
        isA<PlaceAcked>()
            .having((o) => o.order.id, 'id', 'ORD7')
            .having((o) => o.order.clientKey, 'key', 'k9'),
      );
      expect(seen.map((r) => r.method), ['POST', 'GET']);
      expect(seen.last.url.queryParameters, {'key': 'k9'});
    });

    test('a 409 whose original cannot be read stays unresolved, never '
        'rejected', () async {
      final repo = repository(
        (request) => request.method == 'POST'
            ? http.Response('{"error":{"code":"duplicate_key"}}', 409)
            : http.Response('{"data":null}', 200),
      );

      expect(
        await repo.place(_request, idempotencyKey: 'k9'),
        isA<PlaceTimedOut>(),
      );
    });

    test('a 422 is rejected with the server reason and sent once', () async {
      final repo = repository(
        (_) => http.Response(
          '{"error":{"code":"insufficient_funds","message":"Need more"}}',
          422,
        ),
      );

      expect(
        await repo.place(_request, idempotencyKey: 'k1'),
        isA<PlaceRejected>().having(
          (o) => o.code,
          'code',
          'insufficient_funds',
        ),
      );
      expect(seen, hasLength(1));
    });
  });
}
