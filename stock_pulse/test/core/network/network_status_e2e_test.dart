import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/data/socket_config.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';

import '../../helpers/test_server.dart';

/// The real server, the real socket and the real status provider: a frozen
/// server keeps the TCP connection open, so only data silence can tell.
void main() {
  test(
    'a frozen server shows Delayed, then Live again when frames resume',
    () async {
      final server = await TestServer.start();
      final socket = MarketSocket(
        server.config.socketUri,
        config: const SocketConfig(
          pingInterval: Duration(milliseconds: 100),
          delayedAfter: Duration(milliseconds: 1500),
          staleAfter: Duration(seconds: 20),
        ),
      );
      final api = ApiClient(server.config);
      final container = ProviderContainer(
        overrides: [
          marketSocketProvider.overrideWithValue(socket),
          apiClientProvider.overrideWithValue(api),
        ],
      );
      final seen = <NetworkStatus>[];
      container.listen(
        networkStatusProvider,
        (_, next) => next.whenData(seen.add),
      );
      addTearDown(() async {
        container.dispose();
        await socket.dispose();
        api.close();
        await server.close();
      });

      socket
        ..start()
        ..subscribeQuotes(['TCS'], FeedMode.ltp);
      await eventually(
        () => seen.lastOrNull == NetworkStatus.live,
        timeout: const Duration(seconds: 10),
      );

      server.server.gateway.freezeAll(const Duration(seconds: 8));
      await eventually(
        () => seen.lastOrNull == NetworkStatus.delayed,
        timeout: const Duration(seconds: 10),
      );
      // The feed becomes delayed well before the socket stale timeout.
      expect(socket.status, isA<SocketConnected>());

      await eventually(
        () => seen.lastOrNull == NetworkStatus.live,
        timeout: const Duration(seconds: 10),
      );
      expect(
        seen,
        containsAllInOrder([
          NetworkStatus.live,
          NetworkStatus.delayed,
          NetworkStatus.live,
        ]),
      );
    },
  );
}
