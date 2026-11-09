import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:option_math/option_math.dart';
import 'package:stock_pulse/features/strategy/application/payoff_geometry.dart';
import 'package:stock_pulse/features/strategy/presentation/widgets/payoff_chart.dart';
import 'package:stock_pulse/features/strategy/presentation/widgets/payoff_painter.dart';

import '../../../helpers/sp_app.dart';

PayoffGeometry _geometry({bool live = false}) => PayoffGeometry.build(
  [
    PayoffLeg(
      right: OptionRight.ce,
      strike: 100,
      side: LegSide.buy,
      units: 10,
      premium: 5,
      iv: .2,
      expiryAt: DateTime.utc(2026, 12),
    ),
  ],
  spot: 100,
  marketNow: live ? DateTime.utc(2026, 11) : null,
);

void main() {
  test(
    'painter draws payoff, today and spot paths and compares dependencies',
    () {
      final geometry = _geometry(live: true);
      final painter = PayoffPainter(
        geometry,
        line: Colors.white,
        up: Colors.green,
        down: Colors.red,
        today: Colors.blue,
        axis: Colors.grey,
      );
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(320, 180));
      recorder.endRecording();
      expect(painter.shouldRepaint(painter), isFalse);
      expect(
        painter.shouldRepaint(
          PayoffPainter(
            geometry,
            line: Colors.black,
            up: Colors.green,
            down: Colors.red,
            today: Colors.blue,
            axis: Colors.grey,
          ),
        ),
        isTrue,
      );
      expect(
        painter.shouldRepaint(
          PayoffPainter(
            _geometry(),
            line: Colors.white,
            up: Colors.green,
            down: Colors.red,
            today: Colors.blue,
            axis: Colors.grey,
          ),
        ),
        isTrue,
      );
    },
  );

  test('crosshair painter responds to value and geometry changes', () {
    final geometry = _geometry();
    final fraction = ValueNotifier<double?>(.5);
    final painter = PayoffCrosshairPainter(geometry, fraction, Colors.orange);
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(320, 180));
    fraction.value = null;
    painter.paint(Canvas(ui.PictureRecorder()), const Size(320, 180));
    expect(painter.shouldRepaint(painter), isFalse);
    expect(
      painter.shouldRepaint(
        PayoffCrosshairPainter(_geometry(live: true), fraction, Colors.orange),
      ),
      isTrue,
    );
    fraction.dispose();
  });

  testWidgets('full chart exposes crosshair while compact chart stays static', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(PayoffChart(geometry: _geometry(), summary: 'Max loss ₹50')),
    );
    expect(find.text('Max loss ₹50'), findsNothing);
    await tester.drag(find.byType(PayoffChart), const Offset(100, 0));
    await tester.pump();
    expect(find.textContaining('₹'), findsWidgets);

    await tester.pumpWidget(
      spApp(
        PayoffChart(geometry: _geometry(), summary: 'Compact', compact: true),
      ),
    );
    expect(tester.getSize(find.byType(PayoffChart)).height, 140);
    expect(find.text('Compact'), findsNothing);
  });

  testWidgets(
    'crosshair label follows the pointer and stays inside the chart',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        spApp(
          SizedBox(
            width: 360,
            child: PayoffChart(geometry: _geometry(), summary: 'Max loss ₹50'),
          ),
        ),
      );
      final chart = tester.getRect(find.byType(PayoffChart));
      final labelFinder = find.textContaining('Spot ');

      await tester.tapAt(Offset(chart.left + 40, chart.center.dy));
      await tester.pump();
      final leftLabel = tester.getRect(labelFinder);
      expect(leftLabel.left, greaterThanOrEqualTo(chart.left));
      expect(leftLabel.right, lessThanOrEqualTo(chart.right));

      await tester.tapAt(Offset(chart.right - 40, chart.center.dy));
      await tester.pump();
      final rightLabel = tester.getRect(labelFinder);
      expect(rightLabel.left, greaterThanOrEqualTo(chart.left));
      expect(rightLabel.right, lessThanOrEqualTo(chart.right));
      expect(rightLabel.center.dx - leftLabel.center.dx, greaterThan(100));
    },
  );

  testWidgets('crossing a breakeven clicks once; a tap sets the crosshair', (
    tester,
  ) async {
    final clicks = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') clicks.add('$call');
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      spApp(
        SizedBox(
          width: 360,
          child: PayoffChart(geometry: _geometry(), summary: 'Max loss ₹50'),
        ),
      ),
    );
    final box = tester.getRect(find.byType(PayoffChart));
    await tester.tapAt(Offset(box.left + 40, box.center.dy));
    await tester.pump();
    await tester.tapAt(Offset(box.left + 40, box.center.dy));
    await tester.pump();
    expect(clicks, isEmpty, reason: 'staying on one side is silent');
    final gesture = await tester.startGesture(
      Offset(box.left + 40, box.center.dy),
    );
    for (var x = 60.0; x < box.width - 10; x += 20) {
      await gesture.moveTo(Offset(box.left + x, box.center.dy));
      await tester.pump();
    }
    await gesture.up();
    expect(clicks, hasLength(1), reason: 'only the breakeven crossing clicks');
  });
}
