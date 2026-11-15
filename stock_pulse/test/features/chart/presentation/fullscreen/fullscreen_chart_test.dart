import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/app_router.dart';
import 'package:stock_pulse/app/router/deep_link.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/widgets/sp_picker_sheet.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/di/drawings_providers.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/chart/presentation/candle_chart.dart';
import 'package:stock_pulse/features/chart/presentation/chart_view.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/presentation/widgets/order_sheet.dart';

import '../../../../helpers/chart_test_market.dart';
import '../../../../helpers/fake_analytics_sink.dart';
import '../../../../helpers/fake_crash_reporter.dart';
import '../../../../helpers/fake_local_prefs.dart';
import '../../../../helpers/fake_market_socket.dart';

void main() {
  test('S-57 full-screen links retain typed chart selection', () {
    final route = AppRoute.fromUri(
      Uri.parse('/stock/TCS/chart?range=1W&interval=15m'),
    );
    expect(route, isA<ChartRoute>());
    expect(route!.location, '/stock/TCS/chart?range=1W&interval=15m');
    expect(
      normaliseLink(Uri.parse('stockpulse://stock/TCS/chart'))?.path,
      '/stock/TCS/chart',
    );
  });
  testWidgets(
    'S-57 expand and exit retain all chart state with no extra fetch',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = CountingMarket();
      final sink = FakeAnalyticsSink();
      repo.candles['TCS'] = [
        for (var i = 0; i < 20; i++)
          Candle(
            start: DateTime.utc(2026, 11, 12, 4, i * 5),
            open: 100,
            high: 110,
            low: 90,
            close: 101,
            volume: 100,
          ),
      ];
      final router = buildAppRouter(
        initialLocation: '/stock/TCS?range=1W&interval=15m',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            marketRepositoryProvider.overrideWithValue(repo),
            chartDirectoryProvider.overrideWithValue(null),
            crashReporterProvider.overrideWithValue(FakeCrashReporter()),
            analyticsProvider.overrideWithValue(
              AnalyticsService(
                [sink],
                FakeCrashReporter(),
                consent: () => true,
              ),
            ),
            localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
            networkStatusProvider.overrideWith((ref) => const Stream.empty()),
            marketSocketProvider.overrideWithValue(FakeMarketSocket()),
            marketClockProvider.overrideWith((ref) => const Stream.empty()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChartView).first),
      );
      final chart = container.read(chartControllerProvider('TCS').notifier);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CandleChart)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(
        container
            .read(chartControllerProvider('TCS'))
            .requireValue
            .crosshairIndex,
        isNotNull,
      );
      await gesture.up();
      await tester.pump();
      expect(
        container
            .read(chartControllerProvider('TCS'))
            .requireValue
            .crosshairIndex,
        isNull,
      );
      chart.setCrosshair(10);
      await chart.selectType(ChartType.line);
      container
          .read(studiesControllerProvider('TCS').notifier)
          .add(const StudySpec(kind: StudyKind.rsi));
      final drawings = container.read(
        drawingsControllerProvider('TCS').notifier,
      );
      drawings.start(DrawingKind.horizontal);
      drawings.place(
        DrawingAnchor(time: DateTime.utc(2026), price: 100),
        tickSize: .05,
      );
      await tester.pumpAndSettle();
      final before = container
          .read(chartControllerProvider('TCS'))
          .requireValue;
      expect(
        (before.range, before.interval),
        (ChartRange.w1, CandleInterval.m15),
      );
      final loads = repo.loads;
      await tester.tap(find.byTooltip('Full-screen chart'));
      await tester.pumpAndSettle();
      expect(router.state.name, ChartRoute.name);
      expect(ChartRoute.fromState(router.state).instrumentId, 'TCS');
      expect(find.text('BUY'), findsOneWidget);
      expect(find.text('SELL'), findsOneWidget);
      await tester.tap(find.text('BUY'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderSheet), findsOneWidget);
      expect(
        sink.events.where((e) => e.name == 'order_sheet_opened'),
        hasLength(1),
      );
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(1000, 600);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(ChartView)).height,
        greaterThanOrEqualTo(360),
      );
      await tester.tap(find.byTooltip('Candle interval'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(SpPickerSheet<CandleInterval>)).width,
        360,
      );
      await tester.tap(find.text('15m'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Studies'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chart type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Line').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('SELL'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderSheet), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Exit full-screen'));
      await tester.pumpAndSettle();
      expect(
        container.read(chartControllerProvider('TCS')).requireValue,
        before,
      );
      expect(repo.loads, loads);
      expect(
        sink.events.where((e) => e.name == 'chart_fullscreen'),
        hasLength(1),
      );
      await tester.pump(const Duration(milliseconds: 500));
    },
  );
}
