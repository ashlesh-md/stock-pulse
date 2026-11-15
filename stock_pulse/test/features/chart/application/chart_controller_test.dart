import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_providers.dart';
import 'package:stock_pulse/features/chart/di/drawings_providers.dart';
import 'package:stock_pulse/features/chart/domain/chart_layout.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

import '../../../helpers/chart_test_market.dart';
import '../../../helpers/fake_analytics_sink.dart';
import '../../../helpers/fake_crash_reporter.dart';
import '../../../helpers/memory_chart_store.dart';

void main() {
  late CountingMarket repo;
  late FakeAnalyticsSink sink;
  late ProviderContainer container;
  final provider = chartControllerProvider('TCS');
  setUp(() {
    repo = CountingMarket();
    final time = DateTime.utc(2026, 11, 12);
    repo.candles['TCS'] = [
      for (var i = 0; i < 12; i++)
        Candle(
          start: time.subtract(Duration(minutes: (11 - i) * 5)),
          open: 100,
          high: 110,
          low: 90,
          close: 100,
          volume: 10,
        ),
    ];
    sink = FakeAnalyticsSink();
    container = ProviderContainer.test(
      overrides: [
        marketRepositoryProvider.overrideWithValue(repo),
        chartDirectoryProvider.overrideWithValue(null),
        chartStoreProvider.overrideWithValue(MemoryChartStore()),
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        analyticsProvider.overrideWithValue(
          AnalyticsService([sink], FakeCrashReporter(), consent: () => true),
        ),
      ],
    );
    container.listen(provider, (_, _) {});
  });
  test(
    'S-53 settings fetch once and emit one event per changed setting',
    () async {
      final controller = container.read(provider.notifier);
      await controller.selectRange(ChartRange.w1);
      await controller.selectInterval(CandleInterval.h1);
      await controller.selectType(ChartType.line);
      await controller.selectType(ChartType.line);
      final state = container.read(provider).requireValue;
      expect(
        (state.range, state.interval, state.type),
        (ChartRange.w1, CandleInterval.h1, ChartType.line),
      );
      expect(repo.loads, 3);
      expect(
        sink.events.where((e) => e.name == 'chart_setting_changed'),
        hasLength(3),
      );
      expect(sink.events.where((e) => e.name == 'chart_opened'), hasLength(1));
    },
  );
  test(
    'S-53 crosshair and immutable layout survive feed and setting changes',
    () async {
      final controller = container.read(provider.notifier);
      controller.setCrosshair(1);
      await container.read(provider.future);
      final drawings = container.read(
        drawingsControllerProvider('TCS').notifier,
      );
      await Future<void>.delayed(Duration.zero);
      final drawing = Drawing(
        id: 'one',
        kind: DrawingKind.horizontal,
        start: DrawingAnchor(time: DateTime.utc(2026), price: 100),
      );
      drawings.start(DrawingKind.horizontal);
      drawings.place(drawing.start, tickSize: 0.05);
      final layout = ChartLayout(
        drawings: [
          Drawing(
            id: container
                .read(drawingsControllerProvider('TCS'))
                .drawings
                .single
                .id,
            kind: DrawingKind.horizontal,
            start: drawing.start,
          ),
        ],
      );
      controller.setCrosshair(10);
      controller.setCrosshair(10);
      await controller.selectInterval(CandleInterval.m1);
      expect(container.read(provider).requireValue.layout, layout);
      expect(container.read(provider).requireValue.crosshairIndex, 10);
      controller.setCrosshair(null);
      expect(container.read(provider).requireValue.crosshairIndex, isNull);
    },
  );
  test('S-53 historical readout ignores ticks in another candle', () async {
    final time = DateTime.utc(2026, 11, 12);
    repo.candles['TCS'] = [
      for (var i = 0; i < 12; i++)
        Candle(
          start: time.subtract(Duration(minutes: (11 - i) * 5)),
          open: 100,
          high: 110,
          low: 90,
          close: 100,
          volume: 10,
        ),
    ];
    await container.read(provider.future);
    container.read(provider.notifier).setCrosshair(10);
    var changes = 0;
    final readout = chartReadoutProvider('TCS');
    container.listen(readout, (_, _) => changes++);
    expect(container.read(readout).$1, repo.candles['TCS']![10]);
    repo.push([
      Quote(
        symbol: 'TCS',
        ltp: 105,
        change: 5,
        changePercent: 5,
        lastTradeTime: time.add(const Duration(seconds: 1)),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(changes, 0);
    container.read(provider.notifier).setCrosshair(null);
    expect(container.read(readout).$1?.close, 105);
  });
  test('S-53 setting commands may be called before initial load', () async {
    await container.read(provider.notifier).selectInterval(CandleInterval.m1);
    expect(container.read(provider).requireValue.interval, CandleInterval.m1);
  });
  test('S-53 type command may be called before initial load', () async {
    await container.read(provider.notifier).selectType(ChartType.area);
    expect(container.read(provider).requireValue.type, ChartType.area);
  });
}
