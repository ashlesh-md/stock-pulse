import 'dart:convert';
import 'dart:math';
import 'package:market_server/market_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late MarketServer server;
  setUp(
    () => server = MarketServer(
      engine: MarketEngine(
        instruments,
        random: Random(2),
        intradayDays: 1,
        dailyDays: 2,
      ),
    ),
  );
  tearDown(() => server.close());
  Future<(int, Map<String, Object?>)> call(
    String method,
    String path, {
    Object? body,
    String? key,
  }) async {
    final response = await server.handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        headers: {
          'authorization': 'Bearer $demoToken',
          'idempotency-key': ?key,
        },
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return (
      response.statusCode,
      jsonDecode(await response.readAsString()) as Map<String, Object?>,
    );
  }

  test('adding funds is idempotent and validates method and amount', () async {
    final before =
        (await call('GET', '/api/v1/funds')).$2['data'] as Map<String, Object?>;
    final body = {'amount': 5000, 'method': 'upi'};
    final first = await call(
      'POST',
      '/api/v1/funds',
      body: body,
      key: 'payment-1',
    );
    final replay = await call(
      'POST',
      '/api/v1/funds',
      body: body,
      key: 'payment-1',
    );
    expect(first.$1, 200);
    expect(first.$2, replay.$2);
    expect(
      (first.$2['data'] as Map)['available'],
      (before['available'] as num) + 5000,
    );
    expect(
      (await call(
        'POST',
        '/api/v1/funds',
        body: {'amount': -1, 'method': 'upi'},
        key: 'bad',
      )).$1,
      400,
    );
    expect(
      (await call(
        'POST',
        '/api/v1/funds',
        body: {'amount': 10, 'method': 'cash'},
        key: 'bad',
      )).$1,
      400,
    );
  });
  test('order lookup works with id and client key', () async {
    final order = await call(
      'POST',
      '/api/v1/orders',
      body: {'symbol': 'TCS', 'side': 'buy', 'type': 'market', 'quantity': 1},
      key: 'order-1',
    );
    final data = order.$2['data'] as Map<String, Object?>;
    expect(
      (await call('GET', '/api/v1/orders/${data['id']}')).$2['data'],
      data,
    );
    expect((await call('GET', '/api/v1/orders?key=order-1')).$2['data'], data);
    expect((await call('GET', '/api/v1/orders/unknown')).$1, 404);
  });

  test(
    'CNC fills debit and credit funds and settle into holdings T+1',
    () async {
      final before =
          (await call('GET', '/api/v1/funds')).$2['data']
              as Map<String, Object?>;
      final bought = await call(
        'POST',
        '/api/v1/orders',
        body: {
          'symbol': 'ITC',
          'side': 'buy',
          'type': 'market',
          'quantity': 2,
          'product': 'cnc',
        },
        key: 'cnc-buy',
      );
      final buyData = bought.$2['data']! as Map<String, Object?>;
      final debit = (buyData['averagePrice']! as num) * 2;
      final afterBuy = (await call('GET', '/api/v1/funds')).$2['data']! as Map;
      expect(afterBuy['available'], (before['available']! as num) - debit);
      expect((await call('GET', '/api/v1/holdings')).$2['data'], isEmpty);

      final nextDay = server.calendar.nextTradingDay(
        Ist.dateOf(server.clock.marketNow()),
      );
      server.clock.jumpTo(Ist.at(nextDay, 9, 0));
      final holdings =
          (await call('GET', '/api/v1/holdings')).$2['data']! as List;
      expect((holdings.single as Map)['quantity'], 2);
      expect((await call('GET', '/api/v1/positions')).$2['data'], isEmpty);

      final sold = await call(
        'POST',
        '/api/v1/orders',
        body: {
          'symbol': 'ITC',
          'side': 'sell',
          'type': 'market',
          'quantity': 1,
          'product': 'cnc',
        },
        key: 'cnc-sell',
      );
      final salePrice = (sold.$2['data']! as Map)['averagePrice']! as num;
      final afterSell = (await call('GET', '/api/v1/funds')).$2['data']! as Map;
      expect(
        afterSell['available'],
        (afterBuy['available']! as num) + salePrice,
      );
      final afterSaleHoldings =
          (await call('GET', '/api/v1/holdings')).$2['data']! as List;
      expect((afterSaleHoldings.single as Map<String, Object?>)['quantity'], 1);
    },
  );

  test('alerts trigger only once and can be cancelled', () async {
    final price = server.engine['TCS']!.ltp;
    final created = await call(
      'POST',
      '/api/v1/alerts',
      body: {
        'symbol': 'TCS',
        'cond': 'above',
        'level': ((price + 1) * 20).round() / 20,
      },
    );
    expect(created.$1, 201);
    final id = (created.$2['data'] as Map)['alertId'];
    server.engine['TCS']!.ltp += 2;
    server.account.evaluateAlerts();
    final list = (await call('GET', '/api/v1/alerts')).$2['data'] as List;
    expect((list.single as Map<String, Object?>)['status'], 'triggered');
    expect((await call('DELETE', '/api/v1/alerts/$id')).$1, 200);
    expect(
      (await call(
        'POST',
        '/api/v1/alerts',
        body: {'symbol': 'BAD', 'cond': 'above', 'level': 10},
      )).$1,
      404,
    );
  });
}
