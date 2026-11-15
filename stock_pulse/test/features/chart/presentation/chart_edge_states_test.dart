import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/chart/presentation/chart_view.dart';
import 'package:stock_pulse/features/chart/presentation/fullscreen/fullscreen_chart_screen.dart';
import 'package:stock_pulse/features/market/application/stock_detail_controller.dart';
import 'package:stock_pulse/features/market/application/stock_detail_state.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

import '../../../helpers/chart_test_market.dart';
import '../../../helpers/fake_crash_reporter.dart';
import '../../../helpers/fake_market_socket.dart';

class _Detail extends StockDetailController {
  _Detail(this.value, {this.fail = false}) : super('TCS');
  final StockDetailState value;
  final bool fail;
  @override
  Future<StockDetailState> build() async {
    if (fail) throw const NetworkError();
    return value;
  }
}

void main() {
  final market = CountingMarket();
  StockDetailState state({bool previous = false, bool empty = false}) =>
      StockDetailState(
        instrument: market.instrument('TCS')!,
        range: ChartRange.d1,
        interval: CandleInterval.m5,
        quote: market.latest('TCS')!,
        previousSession: previous,
        candles: empty
            ? []
            : [
                Candle(
                  start: DateTime.utc(2026),
                  open: 100,
                  high: 110,
                  low: 90,
                  close: 100,
                  volume: 1,
                ),
              ],
      );
  ProviderContainer container(StockDetailState state, {bool fail = false}) =>
      ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          stockDetailControllerProvider('TCS')
              .overrideWith(() => _Detail(state, fail: fail)),
          chartDirectoryProvider.overrideWithValue(null),
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
          analyticsProvider.overrideWithValue(
            AnalyticsService(
              const [],
              FakeCrashReporter(),
              consent: () => true,
            ),
          ),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
          marketClockProvider.overrideWith((ref) => const Stream.empty()),
          marketSocketProvider.overrideWithValue(FakeMarketSocket()),
        ],
      );
  testWidgets(
    'B25 chart labels the previous session and explains an empty history',
    (tester) async {
      for (final empty in [false, true]) {
        final c = container(state(previous: !empty, empty: empty));
        addTearDown(c.dispose);
        c.listen(stockDetailControllerProvider('TCS'), (_, _) {});
        await c.read(stockDetailControllerProvider('TCS').future);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp(
              theme: AppTheme.dark(),
              home: const SizedBox(
                height: 320,
                child: ChartView(instrumentId: 'TCS'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            empty
                ? 'No price data is available for this session.'
                : 'Previous session',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
  testWidgets(
    'full-screen loading failure offers Retry and standalone exit recovers the stock route',
    (tester) async {
      final c = container(state(), fail: true);
      addTearDown(c.dispose);
      c.listen(stockDetailControllerProvider('TCS'), (_, _) {});
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const FullscreenChartScreen(instrumentId: 'TCS'),
          ),
          GoRoute(
            path: StockRoute.path,
            builder: (_, _) => const Text('Stock recovered'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.byTooltip('Exit full-screen'));
      await tester.pumpAndSettle();
      expect(find.text('Stock recovered'), findsOneWidget);
    },
  );
}
