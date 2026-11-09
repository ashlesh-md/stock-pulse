import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/features/portfolio/data/live_portfolio_repository.dart';

import '../../helpers/fake_market_socket.dart';

/// Bodies recorded from the current market_server after one market buy.
const _order =
    '{"id":"ORD000001","product":"cnc","lots":null,"triggerPrice":null,'
    '"clientKey":"k1","version":2,"symbol":"RELIANCE","side":"buy",'
    '"type":"market","quantity":1,"limitPrice":null,"status":"complete",'
    '"averagePrice":1385.5,"message":null,"reason":null,'
    '"createdAt":"2026-11-09T04:47:44.526811Z",'
    '"updatedAt":"2026-11-09T04:47:44.527057Z"}';
const _row =
    '{"symbol":"RELIANCE","product":"cnc","version":2,"quantity":1,'
    '"averagePrice":1385.5,"realizedPnl":0.0}';
const _bodies = {
  '/api/v1/orders': '{"data":[$_order]}',
  '/api/v1/positions': '{"data":[$_row]}',
  '/api/v1/holdings': '{"data":[$_row]}',
  '/api/v1/funds': '{"data":{"available":1010000.0,"version":1}}',
};

void main() {
  test('the current server bodies for orders, positions, holdings and funds '
      'all parse', () async {
    final api = ApiClient(
      const AppConfig(host: 'localhost'),
      client: MockClient(
        (request) async => http.Response(_bodies[request.url.path]!, 200),
      ),
    );
    addTearDown(api.close);
    final repository = LivePortfolioRepository(api, FakeMarketSocket());

    final orders = await repository.getOrders();
    final positions = await repository.getPositions();
    final holdings = await repository.getHoldings();
    final funds = await repository.getFunds();

    expect(orders, isA<Success<Object?>>());
    expect(positions, isA<Success<Object?>>());
    expect(holdings, isA<Success<Object?>>());
    expect(funds, isA<Success<Object?>>());
    expect(orders.getOrThrow().single.averagePrice, 1385.5);
    expect(positions.getOrThrow().single.quantity, 1);
  });
}
