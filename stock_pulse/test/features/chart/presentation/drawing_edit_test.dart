import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/chart/di/drawings_providers.dart';
import 'package:stock_pulse/features/chart/domain/chart_layout.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/drawing_geometry.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_action_bar.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_handle.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_layer.dart';

import '../../../helpers/memory_chart_store.dart';
import '../../../helpers/sp_app.dart';

void main() {
  testWidgets(
    'S-55 restored trend line can be selected and both body and end dragged',
    (tester) async {
      final time = DateTime.utc(2026);
      final store = MemoryChartStore()
        ..layout = ChartLayout(
          drawings: [
            Drawing(
              id: 'saved',
              kind: DrawingKind.trendLine,
              start: DrawingAnchor(
                time: time.add(const Duration(hours: 6)),
                price: 150,
              ),
              end: DrawingAnchor(
                time: time.add(const Duration(hours: 18)),
                price: 150,
              ),
            ),
          ],
        );
      final geometry = DrawingGeometry(
        first: time,
        last: time.add(const Duration(days: 1)),
        low: 100,
        high: 200,
        width: 300,
        height: 200,
      );
      await tester.pumpWidget(
        spApp(
          Column(
            children: [
              SizedBox(
                width: 300,
                height: 200,
                child: DrawingLayer(
                  instrumentId: 'TCS',
                  geometry: geometry,
                  tickSize: .05,
                ),
              ),
              const DrawingActionBar(instrumentId: 'TCS'),
            ],
          ),
          overrides: [chartStoreProvider.overrideWithValue(store)],
        ),
      );
      await tester.pump();
      final origin = tester.getTopLeft(find.byType(DrawingLayer));
      await tester.tapAt(origin + const Offset(150, 100));
      await tester.pump();
      expect(find.byType(DrawingHandle), findsNWidgets(2));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrawingLayer)),
      );
      final provider = drawingsControllerProvider('TCS');
      await tester.drag(find.byType(DrawingHandle).last, const Offset(0, 20));
      await tester.pump();
      expect(container.read(provider).drawings.single.start.price, 150);
      expect(
        container.read(provider).drawings.single.end!.price,
        lessThan(150),
      );
      final before = container.read(provider).drawings.single;
      final (ax, ay) = geometry.project(before.start);
      final (bx, by) = geometry.project(before.end!);
      await tester.dragFrom(
        origin + Offset((ax + bx) / 2, (ay + by) / 2),
        const Offset(35, 35),
      );
      await tester.pump();
      expect(
        container.read(provider).drawings.single.start,
        isNot(before.start),
      );
      container.read(provider.notifier).start(DrawingKind.horizontal);
      await tester.pump();
      await tester.tap(find.text('Cancel drawing'));
      await tester.pump();
      expect(container.read(provider).mode, isNull);
      await tester.pump(const Duration(milliseconds: 500));
    },
  );
}
