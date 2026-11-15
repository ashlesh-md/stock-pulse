import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/l10n/locales/en/market_strings_en.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/features/chart/presentation/candle_chart.dart';
import 'package:stock_pulse/features/chart/presentation/candle_painter.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

import '../../helpers/sp_app.dart';
import 'candle_chart_data.dart';

void main() {
  group('CandlePainter', () {
    CandlePainter painter({
      ChartType type = ChartType.candles,
      int? crosshair,
      double? baseline = 100,
      List<Candle>? data,
      CandleInterval interval = CandleInterval.m5,
      bool logScale = false,
    }) => CandlePainter(
      candles: data ?? testCandles(30),
      type: type,
      interval: interval,
      baseline: baseline,
      candleWidth: 8,
      offset: 0,
      crosshair: crosshair,
      gridColor: const Color(0xFF333333),
      textStyle: const TextStyle(fontSize: 10, color: Color(0xFF999999)),
      labelBackground: const Color(0xFF222222),
      colors: SpColors.dark,
      strings: const MarketStringsEn(),
      logScale: logScale,
    );

    void paint(CandlePainter p) {
      final recorder = ui.PictureRecorder();
      p.paint(Canvas(recorder), const Size(400, 300));
      recorder.endRecording().dispose();
    }

    test('paints every chart type with a crosshair without throwing', () {
      for (final type in ChartType.values) {
        paint(painter(type: type, crosshair: 25));
      }
      paint(painter(crosshair: 25, interval: CandleInterval.d1));
      paint(painter(data: const []));
      paint(painter(baseline: null));
      paint(painter(logScale: true, crosshair: 3));
    });

    test('shouldRepaint only on a drawn change', () {
      final a = painter();
      expect(a.shouldRepaint(a), isFalse);
      expect(painter().shouldRepaint(a), isTrue, reason: 'new candle list');
      final same = CandlePainter(
        candles: a.candles,
        type: a.type,
        interval: a.interval,
        baseline: a.baseline,
        candleWidth: a.candleWidth,
        offset: a.offset,
        crosshair: 3,
        gridColor: a.gridColor,
        textStyle: a.textStyle,
        labelBackground: a.labelBackground,
        colors: a.colors,
        strings: a.strings,
      );
      expect(same.shouldRepaint(a), isTrue);
    });
  });

  group('CandleChart gestures', () {
    Future<void> pump(WidgetTester tester, ChartType type) => tester.pumpWidget(
      spApp(
        SizedBox(
          width: 400,
          height: 300,
          child: CandleChart(
            candles: testCandles(200),
            interval: CandleInterval.m5,
            type: type,
          ),
        ),
      ),
    );

    testWidgets('pinch, pan, wheel, double-tap and long-press', (tester) async {
      await pump(tester, ChartType.candles);
      final chart = find.byType(CandleChart);
      final centre = tester.getCenter(chart);

      final a = await tester.startGesture(centre - const Offset(20, 0));
      final b = await tester.startGesture(centre + const Offset(20, 0));
      await tester.pump();
      await a.moveBy(const Offset(-40, 0));
      await b.moveBy(const Offset(40, 0));
      await tester.pump();
      await a.up();
      await b.up();

      await tester.drag(chart, const Offset(120, 0));
      await tester.pump();

      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: centre, scrollDelta: const Offset(0, 20)),
      );
      tester.binding.handlePointerEvent(
        PointerScrollEvent(position: centre, scrollDelta: const Offset(0, -20)),
      );
      await tester.pump();

      await tester.tap(chart);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(chart);
      await tester.pumpAndSettle();

      final press = await tester.startGesture(centre);
      await tester.pump(const Duration(seconds: 1));
      await press.moveBy(const Offset(30, 0));
      await tester.pump();
      await press.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('reports selected and released crosshair indices', (
      tester,
    ) async {
      final selected = <int?>[];
      await tester.pumpWidget(
        spApp(
          SizedBox(
            width: 400,
            height: 300,
            child: CandleChart(
              candles: testCandles(200),
              interval: CandleInterval.m5,
              onCrosshairChanged: selected.add,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.longPress(find.byType(CandleChart));
      await tester.pump();

      expect(selected, contains(isNotNull));
      expect(selected.last, isNull);
    });

    testWidgets('line charts render', (tester) async {
      await pump(tester, ChartType.area);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
      'keyboard arrows and horizontal wheel pan; overlay gets scale',
      (tester) async {
        double? overlayWidth;
        int? overlayOffset;
        await tester.pumpWidget(
          spApp(
            SizedBox(
              width: 400,
              height: 300,
              child: CandleChart(
                candles: testCandles(500),
                interval: CandleInterval.m5,
                overlayBuilder: (width, offset) {
                  overlayWidth = width;
                  overlayOffset = offset;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        );
        await tester.pump();
        final chart = find.byType(CandleChart);
        CandlePainter painter() => tester
            .widgetList<CustomPaint>(
              find.descendant(of: chart, matching: find.byType(CustomPaint)),
            )
            .map((w) => w.painter)
            .whereType<CandlePainter>()
            .single;
        expect(overlayWidth, greaterThan(0));
        expect(overlayOffset, 0);

        tester
            .widget<Focus>(
              find.descendant(of: chart, matching: find.byType(Focus)),
            )
            .focusNode!
            .requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(painter().offset, greaterThan(0));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(painter().offset, 0);

        final centre = tester.getCenter(chart);
        tester.binding.handlePointerEvent(
          PointerScrollEvent(
            position: centre,
            scrollDelta: const Offset(-24, 0),
          ),
        );
        await tester.pump();
        expect(painter().offset, greaterThan(0));
        expect(overlayOffset, painter().offset);
      },
    );
  });
}
