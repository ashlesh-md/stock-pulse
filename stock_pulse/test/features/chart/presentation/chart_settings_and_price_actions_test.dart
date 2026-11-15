import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/router/app_router.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/alerts/presentation/widgets/create_alert_form.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_providers.dart';
import 'package:stock_pulse/features/chart/di/drawings_providers.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/presentation/chart_view.dart';
import 'package:stock_pulse/features/chart/presentation/crosshair_layer.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/presentation/widgets/order_sheet.dart';

import '../../../helpers/chart_test_market.dart';
import '../../../helpers/fake_crash_reporter.dart';
import '../../../helpers/fake_local_prefs.dart';
import '../../../helpers/fake_market_socket.dart';
import '../../../helpers/memory_chart_store.dart';

void main() {
  late MemoryChartStore store;

  Future<ProviderContainer> pumpStock(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = CountingMarket();
    repo.candles['TCS'] = [
      for (var i = 0; i < 20; i++)
        Candle(
          start: DateTime.utc(2026, 11, 12, 4, i * 5),
          open: 100.0 + i,
          high: 112.0 + i,
          low: 95.0 + i,
          close: 101.0 + i,
          volume: 100,
        ),
    ];
    store = MemoryChartStore();
    final router = buildAppRouter(
      initialLocation: '/stock/TCS?range=1W&interval=15m',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketRepositoryProvider.overrideWithValue(repo),
          chartStoreProvider.overrideWithValue(store),
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
          analyticsProvider.overrideWithValue(
            AnalyticsService([], FakeCrashReporter(), consent: () => true),
          ),
          localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
          marketSocketProvider.overrideWithValue(FakeMarketSocket()),
          marketClockProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(ChartView).first),
    );
  }

  testWidgets('S-72 settings sheet toggles log scale and gridlines', (
    tester,
  ) async {
    final container = await pumpStock(tester);

    await tester.tap(find.byTooltip('Chart settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logarithmic scale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gridlines'));
    await tester.pumpAndSettle();

    final state = container.read(chartControllerProvider('TCS')).requireValue;
    expect((state.logScale, state.gridlines), (true, false));
    expect((store.prefs.logScale, store.prefs.gridlines), (true, false));

    await tester.tap(find.text('Gridlines'));
    await tester.pumpAndSettle();
    expect(store.prefs.gridlines, isTrue);
  });

  testWidgets('S-73 a crosshair price offers an alert and tick-snapped '
      'limit orders', (tester) async {
    final container = await pumpStock(tester);
    container.read(chartControllerProvider('TCS').notifier).setCrosshair(5);
    await tester.pumpAndSettle();

    expect(find.text('Set alert'), findsOneWidget);
    final crosshairClose = container
        .read(stockDetailControllerProvider('TCS'))
        .requireValue
        .candles[5]
        .close;
    expect(
      tester.widget<CrosshairLayer>(find.byType(CrosshairLayer)).price,
      crosshairClose,
    );
    await tester.tap(find.text('Set alert'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateAlertForm), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buy limit'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderSheet), findsOneWidget);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    container.read(chartControllerProvider('TCS').notifier).setCrosshair(null);
    await tester.pumpAndSettle();
    expect(find.text('Set alert'), findsNothing);
  });

  testWidgets('S-73 a selected horizontal line offers the same actions', (
    tester,
  ) async {
    final container = await pumpStock(tester);
    final drawings = container.read(drawingsControllerProvider('TCS').notifier);
    drawings.start(DrawingKind.horizontal);
    drawings.place(
      DrawingAnchor(time: DateTime.utc(2026, 11, 12, 4, 30), price: 104.3),
      tickSize: .05,
    );
    await tester.pumpAndSettle();
    final id = container
        .read(drawingsControllerProvider('TCS'))
        .drawings
        .single
        .id;
    drawings.select(id);
    await tester.pumpAndSettle();

    expect(find.text('Sell limit'), findsOneWidget);
    await tester.tap(find.text('Sell limit'));
    await tester.pumpAndSettle();
    expect(find.byType(OrderSheet), findsOneWidget);
  });
}
