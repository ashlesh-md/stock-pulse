import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/app_shell_scaffold.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/features/market/presentation/screens/stock_detail_screen.dart';
import 'package:stock_pulse/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screen and app lifecycle release and restore subscriptions', (
    tester,
  ) async {
    final client = HttpClient();
    addTearDown(client.close);
    app.main();
    await tester.pump();

    final shell = find.byType(AppShellScaffold, skipOffstage: false);
    await tester.pump(const Duration(seconds: 2));
    final container = ProviderScope.containerOf(tester.element(shell));
    final router = container.read(goRouterProvider);

    Future<Map<String, Object?>> readSubscriptions() async {
      final request = await client.getUrl(
        Uri.parse('http://localhost:8080/debug/subscriptions'),
      );
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('subscriptions endpoint: ${response.statusCode}');
      }
      return jsonDecode(await utf8.decodeStream(response))
          as Map<String, Object?>;
    }

    Future<Map<String, Object?>> until(
      bool Function(Map<String, Object?>) ready,
      String reason, {
      Duration timeout = const Duration(seconds: 12),
    }) async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        final snapshot = await tester.runAsync(readSubscriptions);
        if (snapshot != null && ready(snapshot)) return snapshot;
        await tester.pump(const Duration(milliseconds: 100));
      }
      fail('Timed out waiting for $reason');
    }

    List<Map<String, Object?>> sessions(Map<String, Object?> response) => [
      for (final value in response['sessions']! as List)
        value as Map<String, Object?>,
    ];

    List<String> quoteIds(Map<String, Object?> response) =>
        (sessions(response).single['quoteIds']! as List).cast<String>();

    final initial = await until(
      (data) => sessions(data).length == 1 && quoteIds(data).isNotEmpty,
      'watchlist quotes to subscribe',
    );
    final initialQuoteIds = quoteIds(initial);
    expect(initialQuoteIds, containsAll(['HDFCBANK', 'NIFTY', 'RELIANCE']));

    router.go(const OptionChainRoute(underlying: 'NIFTY').location);
    await tester.pump();
    router.go(const WatchlistRoute().location);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final afterTabFlip = await tester.runAsync(readSubscriptions);
    expect(quoteIds(afterTabFlip!), initialQuoteIds);
    expect(
      sessions(afterTabFlip).single['quoteUnsubscribeCount'],
      sessions(initial).single['quoteUnsubscribeCount'],
      reason: 'the 300 ms quote linger avoids an unsubscribe on fast flips',
    );

    unawaited(router.push(const StockRoute('RELIANCE').location));
    await tester.pumpAndSettle();
    expect(find.byType(StockDetailScreen), findsOneWidget);
    final onStock = await until(
      (data) =>
          sessions(data).length == 1 &&
          quoteIds(data).length == 1 &&
          quoteIds(data).single == 'RELIANCE',
      'watchlist quote ids to release while the stock quote stays held',
    );
    expect(quoteIds(onStock), ['RELIANCE']);

    router.pop();
    await tester.pumpAndSettle();
    await until(
      (data) =>
          sessions(data).length == 1 &&
          quoteIds(data).length == initialQuoteIds.length,
      'watchlist quotes to restore after popping the stock page',
    );

    final socket = container.read(marketSocketProvider);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    // Wait on wall time without pumping frames: a multi-second test pump can
    // block on pending platform frames after the integration app is hidden.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    expect(socket.status, isA<SocketPaused>());
    await until(
      (data) => (data['totals']! as Map)['sessions'] == 0,
      'the hidden app socket to close',
      timeout: const Duration(seconds: 2),
    );
    expect(socket.status, isA<SocketPaused>());

    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 10)),
    );
    final stillHidden = await tester.runAsync(readSubscriptions);
    expect((stillHidden!['totals']! as Map)['sessions'], 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final resumed = await until(
      (data) =>
          sessions(data).length == 1 &&
          quoteIds(data).length == initialQuoteIds.length,
      'the shown app socket and watchlist quotes to restore once',
    );
    expect(sessions(resumed), hasLength(1));
    expect(quoteIds(resumed), initialQuoteIds);
  });
}
