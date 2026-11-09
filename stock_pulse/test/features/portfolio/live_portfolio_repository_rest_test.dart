import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/features/orders/domain/order.dart'
    show OrderSide, OrderType;
import 'package:stock_pulse/features/portfolio/data/live_portfolio_repository.dart';

import '../../helpers/fake_market_socket.dart';

const _order = {
  'id': 'ORD1',
  'symbol': 'TCS',
  'side': 'buy',
  'type': 'limit',
  'quantity': 1,
  'status': 'open',
  'limitPrice': 2900,
  'createdAt': '2026-11-10T04:00:00.000Z',
  'updatedAt': '2026-11-10T04:00:00.000Z',
};

const _position = {
  'symbol': 'TCS',
  'quantity': 1,
  'averagePrice': 2900,
  'realizedPnl': 0,
};

void main() {
  late List<http.Request> seen;

  LivePortfolioRepository repo(Object Function(http.Request req) answer) {
    seen = [];
    return LivePortfolioRepository(
      ApiClient(
        const AppConfig(host: '127.0.0.1'),
        client: MockClient((req) async {
          seen.add(req);
          final body = answer(req);
          return body is http.Response
              ? body
              : http.Response(jsonEncode(body), 200);
        }),
      ),
      FakeMarketSocket(),
    );
  }

  test('getOrders parses the list; a failure passes through', () async {
    final orders = await repo(
      (_) => {
        'data': [_order],
      },
    ).getOrders();
    expect(orders.valueOrNull?.single.limitPrice, 2900);
    final failed = await repo((_) => http.Response('', 500)).getOrders();
    expect((failed as Failure).error, isA<ServerError>());
  });

  test(
    'getPositions updates the current book; watchPositions starts with REST',
    () async {
      final r = repo(
        (_) => {
          'data': [_position],
        },
      );
      expect(r.current, isNull);
      final positions = await r.watchPositions().take(1).toList();
      expect(positions.single.single.symbol, 'TCS');
      expect(r.current?.positions.single.averagePrice, 2900);
      expect(r.current?.holdings, isEmpty);
    },
  );

  test('a limit order sends its price; cancel deletes by id', () async {
    final r = repo((req) => {'data': _order});
    final placed = await r.placeOrder(
      symbol: 'TCS',
      side: OrderSide.buy,
      type: OrderType.limit,
      quantity: 1,
      limitPrice: 2900,
    );
    expect(jsonDecode(seen.single.body), containsPair('limitPrice', 2900.0));
    expect(placed.valueOrNull?.id, 'ORD1');
    await r.cancelOrder('ORD1');
    expect(seen.last.method, 'DELETE');
    expect(seen.last.url.path, '/api/v1/orders/ORD1');
  });

  test(
    'holdings and funds load their REST snapshots and update current book',
    () async {
      final r = repo(
        (request) => request.url.path.endsWith('funds')
            ? {
                'data': {'available': 1000, 'version': 1},
              }
            : {
                'data': [_position],
              },
      );
      expect((await r.getHoldings()).valueOrNull?.single.symbol, 'TCS');
      expect((await r.getFunds()).valueOrNull?.available, 1000);
      expect((await r.watchFunds().first).version, 1);
      expect((await r.watchHoldings().first).single.quantity, 1);
      expect(r.current?.funds?.available, 1000);
    },
  );
}
