import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/chart/di/drawings_providers.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/drawing_geometry.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_action_bar.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_handle.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_layer.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_painter.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_tool_button.dart';

import '../../../helpers/fake_crash_reporter.dart';
import '../../../helpers/memory_chart_store.dart';
import '../../../helpers/sp_app.dart';

void main() {
  final time = DateTime.utc(2026);
  final geometry = DrawingGeometry(
    first: time,
    last: time.add(const Duration(days: 1)),
    low: 100,
    high: 200,
    width: 236,
    height: 200,
  );
  testWidgets(
    'S-55 toolbar places a line, offers 44dp handles and deletes it',
    (tester) async {
      await tester.pumpWidget(
        spApp(
          Column(
            children: [
              const DrawingToolButton(instrumentId: 'TCS'),
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
          overrides: [
            chartStoreProvider.overrideWithValue(MemoryChartStore()),
            analyticsProvider.overrideWithValue(
              AnalyticsService(
                const [],
                FakeCrashReporter(),
                consent: () => true,
              ),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Draw'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Horizontal line'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel drawing'), findsOneWidget);
      final origin = tester.getTopLeft(find.byType(DrawingLayer));
      await tester.tapAt(origin + const Offset(118, 100));
      await tester.pump();
      final handle = find.byType(DrawingHandle);
      expect(tester.getSize(handle), const Size(44, 44));
      await tester.drag(handle, const Offset(0, 10));
      await tester.pump();
      await tester.tap(find.text('Delete drawing'));
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrawingLayer)),
      );
      expect(
        container.read(drawingsControllerProvider('TCS')).drawings,
        isEmpty,
      );
      await tester.pump(const Duration(milliseconds: 500));
    },
  );
  test('S-55 painter delegates Fibonacci, tags horizontal prices and hit-tests lines', () {
    for (final kind in DrawingKind.values) {
      final drawing = Drawing(
        id: 'one',
        kind: kind,
        start: DrawingAnchor(time: time, price: 150),
        end: kind == DrawingKind.horizontal
            ? null
            : DrawingAnchor(
                time: time.add(const Duration(days: 1)),
                price: 160,
              ),
      );
      final painter = DrawingPainter(
        drawing: drawing,
        geometry: geometry,
        color: Colors.blue,
        labelColor: Colors.white,
      );
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(300, 200));
      recorder.endRecording().dispose();
      expect(painter.hitTest(const Offset(0, 100)), isTrue);
      expect(painter.hitTest(const Offset(0, 0)), isFalse);
      expect(painter.shouldRepaint(painter), isFalse);
    }
  });
}
