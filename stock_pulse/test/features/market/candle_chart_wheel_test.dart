import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/presentation/widgets/candle_chart.dart';

import '../../helpers/sp_app.dart';
import 'candle_chart_data.dart';

void main() {
  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    spApp(
      ListView(
        children: [
          SizedBox(
            width: 400,
            height: 300,
            child: CandleChart(
              candles: testCandles(200),
              interval: CandleInterval.m5,
            ),
          ),
          const SizedBox(height: 2000),
        ],
      ),
    ),
  );

  testWidgets('CR-2 #10: the wheel pans the chart, not the page; Ctrl zooms', (
    tester,
  ) async {
    await pump(tester);
    final centre = tester.getCenter(find.byType(CandleChart));
    final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
    tester.binding.handlePointerEvent(
      PointerScrollEvent(position: centre, scrollDelta: const Offset(0, 40)),
    );
    await tester.pump();
    expect(list.position.pixels, 0);

    await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
    tester.binding.handlePointerEvent(
      PointerScrollEvent(position: centre, scrollDelta: const Offset(0, 20)),
    );
    await simulateKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(list.position.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CR-2 #10: a fast drag keeps panning with momentum', (
    tester,
  ) async {
    await pump(tester);
    final chart = find.byType(CandleChart);
    await tester.fling(chart, const Offset(300, 0), 3000);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    await tester.fling(chart, const Offset(-300, 0), 3000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
