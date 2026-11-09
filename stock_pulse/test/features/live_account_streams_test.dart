import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/features/alerts/data/live_alerts_repository.dart';
import 'package:stock_pulse/features/options/data/live_chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/portfolio/data/live_portfolio_repository.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';

import '../helpers/fake_market_socket.dart';

void main() {
  late FakeMarketSocket socket;
  late ApiClient api;
  setUp(() {
    socket = FakeMarketSocket();
  });
  tearDown(() async {
    api.close();
    await socket.dispose();
  });
  test('funds initial snapshot, live updates and older REST reconciliation preserve newest version', () async {
    api = ApiClient(
      const AppConfig(host: 'test'),
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': {'available': 100, 'version': 1},
          }),
          200,
        ),
      ),
    );
    final repo = LivePortfolioRepository(api, socket);
    final values = <Funds>[];
    final sub = repo.watchFunds().listen(values.add);
    await Future<void>.delayed(Duration.zero);
    expect(values.last.available, 100);
    socket.emit({
      'type': 'funds',
      'data': {'available': 200, 'version': 2},
    });
    socket.emitResyncNeeded();
    await Future<void>.delayed(Duration.zero);
    expect(values.last, const Funds(available: 200, version: 2));
    await sub.cancel();
    expect(socket.accountSubs.single.isCancelled, isTrue);
  });
  test(
    'position frames during a REST reload replay after its snapshot',
    () async {
      final response = Completer<http.Response>();
      api = ApiClient(
        const AppConfig(host: 'test'),
        client: MockClient((_) => response.future),
      );
      final repo = LivePortfolioRepository(api, socket);
      final values = <List<int>>[];
      final sub = repo.watchPositions().listen((positions) {
        values.add([for (final position in positions) position.quantity]);
      });

      socket.emit({
        'type': 'position',
        'data': {
          'symbol': 'RELIANCE',
          'product': 'mis',
          'version': 2,
          'quantity': 2,
          'averagePrice': 100,
          'realizedPnl': 0,
        },
      });
      expect(values, isEmpty);

      response.complete(http.Response(jsonEncode({'data': <Object?>[]}), 200));
      await Future<void>.delayed(Duration.zero);
      expect(values, [
        <int>[],
        [2],
      ]);
      await sub.cancel();
    },
  );
  test(
    'alert trigger stream seeds history and announces a new version once',
    () async {
      final alert = <String, Object?>{
        'alertId': 'A',
        'symbol': 'TCS',
        'cond': 'above',
        'level': 10,
        'createdAt': '2026-01-01T00:00:00Z',
        'status': 'active',
        'version': 1,
      };
      api = ApiClient(
        const AppConfig(host: 'test'),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [alert],
            }),
            200,
          ),
        ),
      );
      final repo = LiveAlertsRepository(api, socket);
      final announced = <String>[];
      final sub = repo.triggered.listen((a) => announced.add(a.alertId));
      await Future<void>.delayed(Duration.zero);
      final triggered = {...alert, 'status': 'triggered', 'version': 2};
      socket.emit({'type': 'alert', 'data': triggered});
      socket.emit({'type': 'alert', 'data': triggered});
      await Future<void>.delayed(Duration.zero);
      expect(announced, ['A']);
      await sub.cancel();
    },
  );
  test(
    'chain snapshot loads rows and a keepalive retains row identity',
    () async {
      final row = {
        'strike': 100,
        'ce': {
          'contractId': 'CE',
          'ltp': 2,
          'change': 0,
          'oi': 100,
          'oiChange': 0,
        },
      };
      final snapshot = {
        'chainId': 'NIFTY:e',
        'spot': 100,
        'atm': 100,
        'status': 'open',
        'asOf': 1,
        'rows': [row],
      };
      api = ApiClient(
        const AppConfig(host: 'test'),
        client: MockClient(
          (_) async => http.Response(jsonEncode({'data': snapshot}), 200),
        ),
      );
      final feed = LiveChainRepository(api, socket).watchChain(
        const ChainRequest(
          underlying: 'NIFTY',
          expiry: 'e',
          fromStrike: 50,
          toStrike: 150,
        ),
      );
      final views = <ChainView>[];
      final sub = feed.views.listen(views.add);
      await Future<void>.delayed(Duration.zero);
      expect(views, hasLength(1));
      socket.emit({
        'type': 'ka',
        'chains': ['NIFTY:e'],
        'asOf': 2,
        'seq': 1,
      });
      await Future<void>.delayed(Duration.zero);
      expect(views, hasLength(2));
      expect(identical(views.first.rows[100], views.last.rows[100]), isTrue);
      expect(views.last.asOf.millisecondsSinceEpoch, 2);
      await sub.cancel();
      expect(socket.chainSubs.single.isCancelled, isTrue);
    },
  );
}
