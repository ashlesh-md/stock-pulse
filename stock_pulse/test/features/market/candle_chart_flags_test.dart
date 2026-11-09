import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/l10n/locales/en/market_strings_en.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/presentation/widgets/candle_chart.dart';
import 'package:stock_pulse/features/market/presentation/widgets/candle_painter.dart';

import '../../helpers/sp_app.dart';
import 'candle_chart_data.dart';

Widget _chart({bool? interactive, bool? showVolume}) => spApp(
  SizedBox(
    width: 300,
    height: 160,
    child: interactive == null && showVolume == null
        ? CandleChart(candles: testCandles(40), interval: CandleInterval.m5)
        : CandleChart(
            candles: testCandles(40),
            interval: CandleInterval.m5,
            interactive: interactive ?? true,
            showVolume: showVolume ?? true,
          ),
  ),
);

CandlePainter _painter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((p) => p.painter)
    .whereType<CandlePainter>()
    .single;

void main() {
  testWidgets('S-18 AC2: defaults keep the interactive chart with volume', (
    tester,
  ) async {
    await tester.pumpWidget(_chart());
    expect(_painter(tester).showVolume, isTrue);
    expect(
      find.descendant(
        of: find.byType(CandleChart),
        matching: find.byType(GestureDetector),
      ),
      findsOneWidget,
    );
  });

  testWidgets('S-18 AC2: interactive false, showVolume false is a static '
      'price-only picture', (tester) async {
    await tester.pumpWidget(_chart(interactive: false, showVolume: false));
    expect(_painter(tester).showVolume, isFalse);
    expect(
      find.descendant(
        of: find.byType(CandleChart),
        matching: find.byType(GestureDetector),
      ),
      findsNothing,
    );
    await tester.drag(find.byType(CandleChart), const Offset(100, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('a showVolume change repaints', () {
    CandlePainter painter({required bool volume}) => CandlePainter(
      candles: const [],
      type: ChartType.candles,
      interval: CandleInterval.m5,
      baseline: null,
      candleWidth: 4,
      offset: 0,
      crosshair: null,
      gridColor: Colors.grey,
      textStyle: const TextStyle(),
      labelBackground: Colors.black,
      colors: SpColors.dark,
      strings: const MarketStringsEn(),
      showVolume: volume,
    );
    expect(painter(volume: false).shouldRepaint(painter(volume: true)), isTrue);
  });
}
