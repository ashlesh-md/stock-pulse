import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/chart/di/drawings_providers.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';

import '../../../../helpers/fake_analytics_sink.dart';
import '../../../../helpers/fake_crash_reporter.dart';
import '../../../../helpers/memory_chart_store.dart';

void main() {
  final anchor = DrawingAnchor(time: DateTime.utc(2026), price: 1500.02);
  final provider = drawingsControllerProvider('TCS');
  late ProviderContainer container;
  late MemoryChartStore store;
  late FakeAnalyticsSink sink;
  setUp(() {
    store = MemoryChartStore();
    sink = FakeAnalyticsSink();
    container = ProviderContainer.test(
      overrides: [
        chartStoreProvider.overrideWithValue(store),
        analyticsProvider.overrideWithValue(
          AnalyticsService([sink], FakeCrashReporter(), consent: () => true),
        ),
      ],
    );
  });
  testWidgets('S-55 one-shot horizontal snaps to tick and saves after 500ms', (
    tester,
  ) async {
    final controller = container.read(provider.notifier);
    await tester.pump();
    controller.start(DrawingKind.horizontal);
    controller.place(anchor, tickSize: .05);
    expect(container.read(provider).drawings.single.start.price, 1500);
    expect(container.read(provider).mode, isNull);
    await tester.pump(const Duration(milliseconds: 499));
    expect(store.writes, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(store.writes, 1);
    expect(sink.events.single.name, 'drawing_added');
  });
  testWidgets(
    'S-55 trend and stored Fib share placement, drag, delete and limit',
    (tester) async {
      final controller = container.read(provider.notifier);
      await tester.pump();
      for (final kind in [DrawingKind.trendLine, DrawingKind.fibRetracement]) {
        controller.start(kind);
        controller.place(anchor, tickSize: .05);
        expect(container.read(provider).mode, kind);
        controller.place(
          DrawingAnchor(
            time: anchor.time.add(const Duration(days: 1)),
            price: 1520,
          ),
          tickSize: .05,
        );
      }
      final line = container.read(provider).drawings.first;
      controller.moveHandle(
        line.id,
        end: true,
        anchor: DrawingAnchor(time: anchor.time, price: 1550.02),
        tickSize: .05,
      );
      expect(container.read(provider).drawings.first.start, line.start);
      expect(container.read(provider).drawings.first.end!.price, 1550);
      controller.moveBody(
        line.id,
        timeDelta: const Duration(hours: 1),
        priceDelta: 10,
        tickSize: .05,
      );
      expect(container.read(provider).drawings.first.start.price, 1510);
      controller.select(line.id);
      controller.deleteSelected();
      for (var i = 1; i < 20; i++) {
        controller.start(DrawingKind.horizontal);
        controller.place(anchor, tickSize: .05);
      }
      controller.start(DrawingKind.horizontal);
      controller.place(anchor, tickSize: .05);
      expect(container.read(provider).drawings, hasLength(20));
      expect(container.read(provider).atLimit, isTrue);
      await tester.pump(const Duration(milliseconds: 500));
      expect(store.writes, 1);
      expect(store.layout.drawings, hasLength(20));
    },
  );
  testWidgets(
    'S-55 F11 failed save keeps drawing, one notice, next edit retries',
    (tester) async {
      store.fail = true;
      final controller = container.read(provider.notifier);
      await tester.pump();
      controller.start(DrawingKind.horizontal);
      controller.place(anchor, tickSize: .05);
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(provider).drawings, hasLength(1));
      expect(container.read(provider).saved, isFalse);
      expect(
        container.read(feedbackControllerProvider)!.text,
        "Couldn't save drawing",
      );
      store.fail = false;
      controller.moveBody(
        container.read(provider).drawings.single.id,
        timeDelta: Duration.zero,
        priceDelta: 1,
        tickSize: .05,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(store.writes, 2);
      expect(container.read(provider).saved, isTrue);
    },
  );
}
