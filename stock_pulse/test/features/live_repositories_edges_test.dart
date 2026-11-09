import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/features/alerts/data/live_alerts_repository.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';
import 'package:stock_pulse/features/options/data/chain_folder.dart';
import 'package:stock_pulse/features/options/data/live_chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/orders/data/live_order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/data/live_portfolio_repository.dart';

import '../helpers/fake_market_socket.dart';

const _alert = <String, Object?>{
  'alertId': 'A',
  'symbol': 'TCS',
  'cond': 'above',
  'level': 10,
  'createdAt': '2026-01-01T00:00:00Z',
  'status': 'active',
  'version': 1,
};

Map<String, Object?> _chain({int asOf = 1, List<Object?>? strikes}) => {
  'chainId': 'NIFTY:2026-11-10',
  'asOf': asOf,
  'spot': 100,
  'atm': 100,
  'strikes': ?strikes,
  'rows': [
    {'strike': 100},
  ],
};

void main() {
  late FakeMarketSocket socket;
  late int status;
  late Object? Function(http.Request) answer;
  late ApiClient api;

  setUp(() {
    socket = FakeMarketSocket();
    status = 200;
    answer = (_) => {'data': <Object?>[]};
    api = ApiClient(
      const AppConfig(host: 'test'),
      client: MockClient(
        (r) async => http.Response(jsonEncode(answer(r)), status),
      ),
    );
  });

  tearDown(() async {
    api.close();
    await socket.dispose();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('alerts', () {
    test('create and delete return the server alert', () async {
      final repo = LiveAlertsRepository(api, socket);
      answer = (_) => {'data': _alert};
      final created = await repo.create('TCS', AlertCondition.above, 10);
      expect((created as Success<PriceAlert>).value.alertId, 'A');
      expect(await repo.delete('A'), isA<Success<PriceAlert>>());
    });

    test('a failed reload is reported on the stream', () async {
      status = 503;
      final errors = <Object>[];
      final sub = LiveAlertsRepository(
        api,
        socket,
      ).watchAll().listen(null, onError: errors.add);
      await settle();
      await settle();
      expect(errors.single, isA<AppError>());
      await sub.cancel();
    });
  });

  group('chain', () {
    const req = ChainRequest(
      underlying: 'NIFTY',
      expiry: '2026-11-10',
      fromStrike: 90,
      toStrike: 110,
    );

    test('expiries are parsed from the REST list', () async {
      answer = (_) => {
        'data': [
          {'code': '2026-11-10', 'expiryAt': 0, 'kind': 'weekly'},
        ],
      };
      final result = await LiveChainRepository(api, socket).expiries('NIFTY');
      expect((result as Success).value, hasLength(1));
    });

    test('chain frames fold in; the visible range is debounced', () async {
      final repo = LiveChainRepository(api, socket);
      final feed = repo.watchChain(req);
      final views = <ChainView>[];
      final sub = feed.views.listen(views.add);
      socket.emit({'type': 'chain', ..._chain(asOf: 5)});
      expect(views.single.rows.keys, [100]);
      feed
        ..setVisibleRange(80, 120)
        ..setVisibleRange(70, 130);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final holder = socket.chainSubs.single;
      expect((holder.fromStrike, holder.toStrike), (70, 130));
      await sub.cancel();
    });

    test('a frame without strikes keeps the previous list', () {
      final first = foldChain(_chain(strikes: [100, 110]));
      final next = foldChain(_chain(asOf: 2), first);
      expect(next.strikes, [100, 110]);
    });
  });

  test('a resync reloads orders into updates and signals completion', () async {
    final repo = LiveOrderRepository(api, socket);
    answer = (_) => {
      'data': [
        {
          'id': 'O1',
          'version': 3,
          'symbol': 'TCS',
          'side': 'buy',
          'type': 'market',
          'quantity': 1,
          'status': 'complete',
          'createdAt': '2026-11-10T04:00:00Z',
          'updatedAt': '2026-11-10T04:00:01Z',
        },
      ],
    };
    final seen = <OrderStatus>[];
    final sub = repo.updates.listen((o) => seen.add(o.status));
    final done = repo.resyncCompleted.first;
    socket.emitResyncNeeded();
    await done;
    expect(seen, [OrderStatus.complete]);
    await sub.cancel();
    await repo.dispose();
  });

  test('account frames that do not parse become stream errors', () async {
    final repo = LivePortfolioRepository(api, socket);
    answer = (_) => {
      'data': {'available': 1, 'version': 1},
    };
    final errors = <Object>[];
    final sub = repo.watchFunds().listen(null, onError: errors.add);
    await settle();
    socket
      ..emit({'type': 'funds', 'data': 'nope'})
      ..emit({
        'type': 'funds',
        'data': {'available': 'x'},
      });
    answer = (_) => {'data': <Object?>[]};
    final positionErrors = <Object>[];
    final positions = repo.watchPositions().listen(
      null,
      onError: positionErrors.add,
    );
    await settle();
    socket.emit({
      'type': 'position',
      'data': {
        'symbol': 'TCS',
        'product': 'unknown',
        'quantity': 1,
        'averagePrice': 1,
        'realizedPnl': 0,
      },
    });
    expect(positionErrors.single, isA<ParseError>());
    await positions.cancel();
    status = 503;
    socket.emitResyncNeeded();
    await settle();
    await settle();
    expect(errors, hasLength(3));
    expect(errors.first, isA<ParseError>());
    expect(errors.last, isA<AppError>());
    await sub.cancel();
  });
}
