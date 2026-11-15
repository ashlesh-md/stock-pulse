import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/features/chart/presentation/fullscreen/fullscreen_chart_screen.dart';
import 'package:stock_pulse/features/market/presentation/screens/stock_detail_screen.dart';
import 'package:stock_pulse/features/market/presentation/screens/watchlist_screen.dart';

import '../../helpers/chart_test_market.dart';
import '../app_harness.dart';

void main() {
  testWidgets('stock Back returns to the page that pushed it', (tester) async {
    final h = AppHarness()..marketRepository = CountingMarket();
    await h.pumpPhone(tester);
    await tester.pumpAndSettle();
    final router = h.router(tester);
    router.push<void>('/stock/TCS').ignore();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WatchlistScreen), findsOneWidget);
  });
  testWidgets('S-57 cold chart route backs through stock to Watchlist root', (
    tester,
  ) async {
    final h = AppHarness()..marketRepository = CountingMarket();
    await h.pumpPhone(tester);
    await tester.pumpAndSettle();
    final router = h.router(tester);
    router.go('/stock/TCS/chart');
    await tester.pumpAndSettle();
    expect(find.byType(FullscreenChartScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Exit full-screen'));
    await tester.pumpAndSettle();
    expect(find.byType(StockDetailScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WatchlistScreen), findsOneWidget);
    expect(router.state.uri.path, WatchlistRoute.path);
  });
  testWidgets(
    'S-57 portrait-to-landscape opens full screen; system back restores stock',
    (tester) async {
      final h = AppHarness()..marketRepository = CountingMarket();
      await h.pumpPhone(tester);
      await tester.pumpAndSettle();
      final router = h.router(tester);
      router.go('/stock/TCS');
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(800, 400);
      await tester.pumpAndSettle();
      expect(find.byType(FullscreenChartScreen), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(StockDetailScreen), findsOneWidget);
    },
  );
}
