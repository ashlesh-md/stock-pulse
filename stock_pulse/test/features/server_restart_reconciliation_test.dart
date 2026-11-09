import 'package:flutter_test/flutter_test.dart';
import 'package:market_server/market_server.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/features/portfolio/data/live_portfolio_repository.dart';

import '../helpers/test_server.dart';

void main() {
  test('positions reconcile after 20 server listener restarts', () async {
    final testServer = await TestServer.start();
    addTearDown(testServer.close);
    final expected = testServer.server.broker.place(
      symbol: 'RELIANCE',
      side: OrderSide.buy,
      type: OrderType.market,
      quantity: 2,
    );
    expect(expected.status, OrderStatus.complete);

    final config = testServer.config;
    final api = ApiClient(config);
    addTearDown(api.close);
    final socket = MarketSocket(config.socketUri);
    addTearDown(socket.dispose);
    final portfolio = LivePortfolioRepository(api, socket);
    final snapshots = <List<int>>[];
    final transientErrors = <Object>[];
    final positions = portfolio.watchPositions().listen((values) {
      snapshots.add([for (final value in values) value.quantity]);
    }, onError: (Object error, StackTrace _) => transientErrors.add(error));
    addTearDown(positions.cancel);
    socket.start();

    await _until(() => snapshots.isNotEmpty);
    final expectedQuantities = [
      for (final position in testServer.server.broker.positions)
        position.quantity,
    ];
    expect(snapshots.last, expectedQuantities);

    for (var i = 0; i < 20; i++) {
      final previousCount = snapshots.length;
      final startedAt = DateTime.now();
      await testServer.restartServer();
      final expectedAfterRestart = [
        for (final position in testServer.server.broker.positions)
          position.quantity,
      ];
      await _until(
        () =>
            socket.status is SocketConnected &&
            snapshots.length > previousCount &&
            snapshots.last.join(',') == expectedAfterRestart.join(','),
        reason: 'positions after restart ${i + 1}',
      );
      expect(
        DateTime.now().difference(startedAt),
        lessThanOrEqualTo(const Duration(seconds: 10)),
      );
    }
  });
}

Future<void> _until(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  String reason = 'condition',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(condition(), isTrue, reason: '$reason was not met within $timeout');
}
