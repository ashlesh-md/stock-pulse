import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/features/market/data/live_market_repository.dart';

import '../helpers/test_server.dart';

/// Wraps a real client and records every request URL.
class RecordingClient extends http.BaseClient {
  final _inner = http.Client();
  final urls = <Uri>[];
  int completed = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    urls.add(request.url);
    final response = await _inner.send(request);
    completed++;
    return response;
  }
}

void main() {
  test('an older snapshot never moves the cached price backwards', () async {
    final responses = [
      {'s': 'TCS', 'ltp': 3010.0, 'ch': 10.0, 'chp': 0.3, 't': 2000},
      {'s': 'TCS', 'ltp': 2990.0, 'ch': -10.0, 'chp': -0.3, 't': 1000}, // stale
    ];
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'data': [responses.removeAt(0)],
        }),
        200,
      ),
    );
    const config = AppConfig(host: 'localhost');
    final socket = MarketSocket(config.socketUri); // never started
    final repo = LiveMarketRepository(
      ApiClient(config, client: client),
      socket,
    );

    await repo.getQuotes(['TCS']);
    await repo.getQuotes(['TCS']);

    expect(repo.latest('TCS')!.ltp, 3010.0);
    await socket.dispose();
  });

  test(
    'a sequence gap reloads every watched symbol over REST (full mode)',
    () async {
      final server = await TestServer.start();
      final recorder = RecordingClient();
      final socket = MarketSocket(server.config.socketUri)..start();
      final repo = LiveMarketRepository(
        ApiClient(server.config, client: recorder),
        socket,
      );

      final sub = repo
          .watchQuotes(['ITC', 'SBIN'], FeedMode.quote)
          .listen((_) {});
      await eventually(
        () => repo.latest('ITC') != null,
      ); // snapshot after subscribe

      server.server.gateway.skipSequence();
      server.step(5);
      await eventually(
        () => recorder.urls.any((u) => u.path == '/api/v1/quotes'),
      );

      final url = recorder.urls.singleWhere((u) => u.path == '/api/v1/quotes');
      expect(url.queryParameters['mode'], 'full');
      expect(
        url.queryParameters['symbols']!.split(','),
        unorderedEquals(['ITC', 'SBIN']),
      );

      await sub.cancel();
      await socket.dispose();
      await server.close();
    },
  );
}
