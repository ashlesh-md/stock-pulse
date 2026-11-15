import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_providers.dart';
import 'package:stock_pulse/features/chart/domain/chart_prefs.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

import '../../../helpers/chart_test_market.dart';
import '../../../helpers/fake_analytics_sink.dart';
import '../../../helpers/fake_crash_reporter.dart';
import '../../../helpers/memory_chart_store.dart';

void main() {
  late MemoryChartStore store;
  late FakeAnalyticsSink sink;
  late ProviderContainer container;
  final provider = chartControllerProvider('TCS');

  setUp(() {
    final repo = CountingMarket();
    repo.candles['TCS'] = [
      Candle(
        start: DateTime.utc(2026, 11, 12, 4),
        open: 100,
        high: 110,
        low: 90,
        close: 100,
        volume: 10,
      ),
    ];
    store = MemoryChartStore()
      ..prefs = const ChartPrefs(logScale: true, gridlines: false);
    sink = FakeAnalyticsSink();
    container = ProviderContainer.test(
      overrides: [
        marketRepositoryProvider.overrideWithValue(repo),
        chartStoreProvider.overrideWithValue(store),
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        analyticsProvider.overrideWithValue(
          AnalyticsService([sink], FakeCrashReporter(), consent: () => true),
        ),
      ],
    );
    container.listen(provider, (_, _) {});
  });

  test('S-72 saved log scale and gridlines load with the chart', () async {
    final state = await container.read(provider.future);
    expect((state.logScale, state.gridlines), (true, false));
  });

  test(
    'S-72 toggles update state, persist once and log one event each',
    () async {
      await container.read(provider.future);
      final controller = container.read(provider.notifier);

      await controller.setLogScale(enabled: false);
      await controller.setGridlines(enabled: true);
      await controller.setGridlines(enabled: true);

      final state = container.read(provider).requireValue;
      expect((state.logScale, state.gridlines), (false, true));
      expect(store.prefs, const ChartPrefs());
      expect(store.prefsWrites, 2);
      final events = sink.events.where(
        (e) => e.name == 'chart_setting_changed',
      );
      expect(events, hasLength(2));
    },
  );

  test('S-72 a toggle before the chart loads is ignored', () async {
    final fresh = ProviderContainer.test(
      overrides: [
        marketRepositoryProvider.overrideWithValue(CountingMarket()),
        chartStoreProvider.overrideWithValue(store),
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        analyticsProvider.overrideWithValue(
          AnalyticsService([sink], FakeCrashReporter(), consent: () => true),
        ),
      ],
    );
    await fresh.read(provider.notifier).setLogScale(enabled: false);
    expect(store.prefsWrites, 0);
  });
}
