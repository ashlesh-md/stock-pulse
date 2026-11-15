import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_pulse/app/bootstrap.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/app_shell_scaffold.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';
import 'package:stock_pulse/features/market/presentation/screens/watchlist_screen.dart';
import 'package:stock_pulse/features/options/presentation/screens/chain_screen.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';
import 'package:stock_pulse/features/orders/presentation/screens/order_ticket_screen.dart';
import 'package:stock_pulse/features/portfolio/presentation/screens/portfolio_screen.dart';

import '../../test/helpers/fake_crash_reporter.dart';
import '../../test/helpers/fake_local_prefs.dart';
import '../../test/helpers/fake_pending_order_store.dart';
import '../../test/helpers/fake_snapshot_store.dart';
import '../../test/helpers/test_server.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'watchlist, chain, ticket and portfolio support 2x text at 360×800',
    (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
      );
      final semantics = tester.ensureSemantics();

      final server = await TestServer.start();
      addTearDown(server.close);
      final root = appScope(
        reporter: FakeCrashReporter(),
        snapshot: Future<AppSnapshot?>.value(),
        overrides: [
          appConfigProvider.overrideWithValue(server.config),
          snapshotStoreProvider.overrideWithValue(FakeSnapshotStore()),
          localPrefsProvider.overrideWith(
            (ref) async => FakeLocalPrefs(
              LocalPrefsData.defaults.copyWith(riskNoticeAcked: true),
            ),
          ),
          fakePendingOrderStoreOverride(),
        ],
      );
      await tester.pumpWidget(root);
      await tester.pump(const Duration(seconds: 1));
      final shell = find.byType(AppShellScaffold);
      await _waitFor(tester, () => shell.evaluate().isNotEmpty);
      final router = ProviderScope.containerOf(tester.element(shell))
          .read(goRouterProvider);

      final routes = [
        (const WatchlistRoute(), WatchlistScreen),
        (const OptionChainRoute(underlying: 'NIFTY'), ChainScreen),
        (
          const OrderTicketRoute(
            OrderTicketArgs(instrumentId: 'RELIANCE', side: OrderSide.buy),
          ),
          OrderTicketScreen,
        ),
        (const PortfolioRoute(), PortfolioScreen),
      ];
      for (final (route, screen) in routes) {
        router.go(route.location);
        await _waitFor(tester, () => find.byType(screen).evaluate().isNotEmpty);
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.byType(screen), findsOneWidget);
        final layoutError = tester.takeException();
        if (layoutError != null) {
          final details = layoutError.toString();
          fail('$route: $details');
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: 'contrast on $route',
        );
      }
      semantics.dispose();
    },
  );
}

Future<void> _waitFor(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(ready(), isTrue, reason: 'app shell should mount');
}
