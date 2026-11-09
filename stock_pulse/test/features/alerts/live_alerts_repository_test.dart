import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/features/alerts/data/live_alerts_repository.dart';

import '../../helpers/fake_market_socket.dart';

void main() {
  test('live trigger and resync snapshot emit the alert only once', () async {
    var listCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path != '/api/v1/alerts') {
        return http.Response('', 404);
      }
      listCalls++;
      final alert = _alert(status: listCalls == 1 ? 'active' : 'triggered');
      return http.Response(
        jsonEncode({
          'data': [alert],
        }),
        200,
      );
    });
    addTearDown(client.close);
    final socket = FakeMarketSocket();
    addTearDown(socket.dispose);
    final repository = LiveAlertsRepository(
      ApiClient(const AppConfig(host: '127.0.0.1'), client: client),
      socket,
    );
    final emitted = <String>[];
    final subscription = repository.triggered.listen(
      (alert) => emitted.add(alert.alertId),
    );
    addTearDown(subscription.cancel);

    await pumpEventQueue();
    expect(listCalls, 1);
    socket.emit({'type': 'alert', 'data': _alert(status: 'triggered')});
    await pumpEventQueue();
    expect(emitted, ['ALT1']);

    socket.emitResyncNeeded();
    await pumpEventQueue();
    expect(listCalls, 2);
    expect(emitted, ['ALT1']);
  });
}

Map<String, Object?> _alert({required String status}) => {
  'alertId': 'ALT1',
  'symbol': 'TCS',
  'cond': 'above',
  'level': 3500,
  'status': status,
  'createdAt': '2026-11-10T04:00:00.000Z',
  'triggeredAt': status == 'triggered' ? '2026-11-10T05:00:00.000Z' : null,
  'triggerLtp': status == 'triggered' ? 3500.5 : null,
  'version': status == 'triggered' ? 2 : 1,
};
