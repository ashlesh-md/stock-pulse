import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/data/live_portfolio_repository.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_book.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';
import 'package:stock_pulse/features/portfolio/domain/settlement.dart';

import '../../../helpers/fake_market_socket.dart';

Map<String, Object?> _order(String status, String updatedAt) => {
  'id': 'O1',
  'symbol': 'TCS',
  'side': 'buy',
  'type': 'market',
  'quantity': 1,
  'status': status,
  'createdAt': '2026-11-10T04:00:00Z',
  'updatedAt': updatedAt,
};

Map<String, Object?> _position(int quantity) => {
  'symbol': 'TCS',
  'product': 'cnc',
  'quantity': quantity,
  'averagePrice': 100,
  'realizedPnl': 0,
};

void main() {
  late FakeMarketSocket socket;
  late List<http.Request> requests;
  late LivePortfolioRepository repo;
  late Map<String, Object?> Function(http.Request) answer;

  setUp(() {
    socket = FakeMarketSocket();
    requests = [];
    answer = (_) => {'data': <Object?>[]};
    repo = LivePortfolioRepository(
      ApiClient(
        const AppConfig(host: 'test'),
        client: MockClient((r) async {
          requests.add(r);
          return http.Response(jsonEncode(answer(r)), 200);
        }),
      ),
      socket,
    );
  });

  tearDown(() => socket.dispose());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test(
    'order updates skip stale versions and a resync replays orders',
    () async {
      final seen = <OrderStatus>[];
      final sub = repo.orderUpdates.listen((o) => seen.add(o.status));
      socket
        ..emit({
          'type': 'order',
          'data': _order('open', '2026-11-10T04:00:02Z'),
        })
        ..emit({
          'type': 'order',
          'data': _order('queued', '2026-11-10T04:00:01Z'),
        });
      answer = (_) => {
        'data': [_order('complete', '2026-11-10T04:00:03Z')],
      };
      socket.emitResyncNeeded();
      await settle();
      expect(seen, [OrderStatus.open, OrderStatus.complete]);
      await sub.cancel();
    },
  );

  test('a position frame replaces the row with the same key', () async {
    answer = (_) => {
      'data': [_position(1)],
    };
    final seen = <List<Position>>[];
    final sub = repo.watchPositions().listen(seen.add);
    await settle();
    socket.emit({'type': 'position', 'data': _position(5)});
    expect(seen.last.single.quantity, 5);
    await sub.cancel();
  });

  test('holding frames and settlements are parsed from the socket', () async {
    final holdings = <List<Holding>>[];
    final settlements = <Settlement>[];
    final a = repo.watchHoldings().listen(holdings.add);
    final b = repo.settlements.listen(settlements.add);
    await settle();
    socket
      ..emit({
        'type': 'holding',
        'data': {'symbol': 'INFY', 'quantity': 3, 'averagePrice': 10},
      })
      ..emit({
        'type': 'settlement',
        'data': {
          'settlementId': 'C@1',
          'symbol': 'NIFTY',
          'product': 'nrml',
          'quantity': 50,
          'settlePrice': 1,
          'pnl': -5,
          'settledAt': '2026-11-10T10:00:00Z',
        },
      });
    await settle();
    expect(holdings.last.single.symbol, 'INFY');
    expect(settlements.single.pnl, -5);
    await a.cancel();
    await b.cancel();
  });

  test('a cached book seeds current once', () {
    final first = PortfolioBook(positions: const [], holdings: const []);
    repo
      ..seedFromCache(first)
      ..seedFromCache(PortfolioBook(positions: const [], holdings: const []));
    expect(repo.current, same(first));
  });

  test('lots and trigger price are sent only when given', () async {
    answer = (_) => {'data': _order('triggerPending', '2026-11-10T04:00:00Z')};
    await repo.placeOrder(
      symbol: 'NIFTY',
      side: OrderSide.buy,
      type: OrderType.sl,
      quantity: 50,
      lots: 1,
      triggerPrice: 99,
      idempotencyKey: 'k',
    );
    final body = jsonDecode(requests.last.body) as Map<String, Object?>;
    expect(body, containsPair('lots', 1));
    expect(body, containsPair('triggerPrice', 99));
    expect(body.containsKey('limitPrice'), isFalse);
  });
}
