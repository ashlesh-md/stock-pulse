import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';

import '../../helpers/fake_market_socket.dart';

void main() {
  testWidgets('a frozen socket becomes delayed and a keepalive restores live', (
    tester,
  ) async {
    final clock = FakeClock(DateTime.utc(2026));
    final socket = FakeMarketSocket(
      status: const SocketConnected(sessionId: 'S'),
    );
    final api = ApiClient(
      const AppConfig(host: 'test'),
      client: MockClient((_) async => http.Response('ok', 200)),
    );
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(clock),
        marketSocketProvider.overrideWithValue(socket),
        apiClientProvider.overrideWithValue(api),
      ],
    );
    final sub = container.listen(networkStatusProvider, (_, _) {});
    await tester.pump();
    expect(sub.read().value, NetworkStatus.live);
    clock.advance(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 6));
    expect(sub.read().value, NetworkStatus.delayed);
    socket.emit({'type': 'ka'}, at: clock.now());
    await tester.pump(const Duration(seconds: 1));
    expect(sub.read().value, NetworkStatus.live);
    container.dispose();
    await socket.dispose();
    api.close();
  });
  testWidgets(
    'failed health probe reports offline while the socket reconnects',
    (tester) async {
      final socket = FakeMarketSocket();
      final api = ApiClient(
        const AppConfig(host: 'test'),
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      final container = ProviderContainer(
        overrides: [
          marketSocketProvider.overrideWithValue(socket),
          apiClientProvider.overrideWithValue(api),
        ],
      );
      final sub = container.listen(networkStatusProvider, (_, _) {});
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(sub.read().value, NetworkStatus.offline);
      container.dispose();
      await socket.dispose();
      api.close();
    },
  );
}
