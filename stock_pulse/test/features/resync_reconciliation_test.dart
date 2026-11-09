import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/features/alerts/data/live_alerts_repository.dart';
import 'package:stock_pulse/features/orders/data/live_order_repository.dart';
import 'package:stock_pulse/features/portfolio/data/live_portfolio_repository.dart';

import '../helpers/fake_market_socket.dart';

void main() {
  test(
    'resync completes after orders, positions and alerts reconcile once',
    () async {
      final socket = FakeMarketSocket();
      addTearDown(socket.dispose);
      final gates = <String, Completer<http.Response>>{
        for (final path in [
          '/api/v1/orders',
          '/api/v1/positions',
          '/api/v1/alerts',
        ])
          path: Completer<http.Response>(),
      };
      var resyncing = false;
      final resyncCalls = <String>{};
      final api = ApiClient(
        const AppConfig(host: 'test'),
        client: MockClient((request) async {
          final path = request.url.path;
          if (resyncing && gates.containsKey(path)) {
            resyncCalls.add(path);
            return gates[path]!.future;
          }
          return http.Response(jsonEncode(_initial(path)), 200);
        }),
      );
      addTearDown(api.close);

      final orders = LiveOrderRepository(api, socket);
      final portfolio = LivePortfolioRepository(api, socket);
      final alerts = LiveAlertsRepository(api, socket);
      addTearDown(orders.dispose);
      final orderEvents = <String>[];
      final positionSnapshots = <List<int>>[];
      final alertEvents = <String>[];
      final orderSub = orders.updates.listen(
        (order) => orderEvents.add(order.id),
      );
      final positionSub = portfolio.watchPositions().listen(
        (positions) => positionSnapshots.add([
          for (final position in positions) position.quantity,
        ]),
      );
      final alertSub = alerts.triggered.listen(
        (alert) => alertEvents.add(alert.alertId),
      );
      addTearDown(orderSub.cancel);
      addTearDown(positionSub.cancel);
      addTearDown(alertSub.cancel);

      await pumpEventQueue();
      resyncing = true;
      socket
        ..emit({'type': 'order', 'data': _order()})
        ..emit({'type': 'alert', 'data': _alert(status: 'triggered')});
      await pumpEventQueue();
      expect(orderEvents, ['ORD1']);
      expect(alertEvents, ['ALT1']);

      var completed = false;
      final completion = orders.resyncCompleted.first.then(
        (_) => completed = true,
      );
      socket.emitResyncNeeded();
      await _until(() => resyncCalls.length == gates.length);
      expect(completed, isFalse);

      gates['/api/v1/orders']!.complete(
        _response({
          'data': [_order()],
        }),
      );
      await pumpEventQueue();
      expect(completed, isFalse);
      gates['/api/v1/positions']!.complete(
        _response({
          'data': [_position()],
        }),
      );
      await pumpEventQueue();
      expect(completed, isFalse);
      gates['/api/v1/alerts']!.complete(
        _response({
          'data': [_alert(status: 'triggered')],
        }),
      );

      await completion;
      await pumpEventQueue();
      expect(positionSnapshots.last, [2]);
      expect(orderEvents, ['ORD1']);
      expect(alertEvents, ['ALT1']);
    },
  );
}

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await pumpEventQueue();
  }
  expect(condition(), isTrue);
}

Map<String, Object?> _initial(String path) => switch (path) {
  '/api/v1/orders' => {'data': <Object?>[]},
  '/api/v1/positions' => {'data': <Object?>[]},
  '/api/v1/alerts' => {
    'data': [_alert(status: 'active')],
  },
  _ => {'data': <Object?>[]},
};

Map<String, Object?> _order() => {
  'id': 'ORD1',
  'version': 3,
  'symbol': 'TCS',
  'product': 'cnc',
  'side': 'buy',
  'type': 'market',
  'quantity': 2,
  'status': 'complete',
  'averagePrice': 100,
  'createdAt': '2026-11-10T04:00:00.000Z',
  'updatedAt': '2026-11-10T04:00:01.000Z',
};

Map<String, Object?> _position() => {
  'symbol': 'TCS',
  'product': 'cnc',
  'version': 2,
  'quantity': 2,
  'averagePrice': 100,
  'realizedPnl': 0,
};

Map<String, Object?> _alert({required String status}) => {
  'alertId': 'ALT1',
  'symbol': 'TCS',
  'cond': 'above',
  'level': 101,
  'status': status,
  'createdAt': '2026-11-10T04:00:00.000Z',
  'triggeredAt': status == 'triggered' ? '2026-11-10T04:01:00.000Z' : null,
  'version': status == 'triggered' ? 2 : 1,
};

http.Response _response(Map<String, Object?> body) =>
    http.Response(jsonEncode(body), 200);
