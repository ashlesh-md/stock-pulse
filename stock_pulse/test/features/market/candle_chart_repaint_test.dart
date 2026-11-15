import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/presentation/candle_chart.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

import '../../helpers/sp_app.dart';
import 'candle_chart_data.dart';

void main() {
  testWidgets('live tick repaints only the live candle layer', (tester) async {
    final counts = {'history': 0, 'live': 0};
    var candles = testCandles(30);
    Widget chart() => spApp(
      SizedBox(
        width: 400,
        height: 300,
        child: CandleChart(
          candles: candles,
          interval: CandleInterval.m5,
          onPainterPainted: (layer) =>
              counts.update(layer, (value) => value + 1, ifAbsent: () => 1),
        ),
      ),
    );

    await tester.pumpWidget(chart());
    await tester.pump();
    final historyPaints = counts['history'];
    final livePaints = counts['live'];
    candles = [
      ...candles.take(candles.length - 1),
      candles.last.copyWith(close: candles.last.close + 1),
    ];
    await tester.pumpWidget(chart());
    await tester.pump();

    expect(counts['history'], historyPaints);
    expect(counts['live'], greaterThan(livePaints!));
  });
}
