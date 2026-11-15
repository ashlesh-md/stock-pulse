import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/presentation/candle_geometry.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

import 'candle_chart_data.dart';

void main() {
  group('CandleGeometry', () {
    test('visibleRange keeps the newest candles that fit', () {
      expect(CandleGeometry.visibleRange(100, 100, 10, 0), (90, 100));
      expect(CandleGeometry.visibleRange(100, 100, 10, 5), (85, 95));
      expect(CandleGeometry.visibleRange(5, 100, 10, 0), (0, 5));
    });
    test('fitWidth clamps between the type minimum and 18', () {
      expect(CandleGeometry.fitWidth(100, 1000, ChartType.line), 0.5);
      expect(CandleGeometry.fitWidth(100, 1000, ChartType.candles), 1.5);
      expect(CandleGeometry.fitWidth(100, 2, ChartType.candles), 18);
      expect(CandleGeometry.fitWidth(100, 0, ChartType.candles), 18);
    });
    test('maxOffset and indexAt stay inside the data', () {
      expect(CandleGeometry.maxOffset(100, 100, 10), 90);
      expect(CandleGeometry.maxOffset(5, 100, 10), 0);
      expect(CandleGeometry.indexAt(15, 100, 100, 10, 0), 91);
      expect(CandleGeometry.indexAt(5000, 100, 100, 10, 0), 99);
    });
    test('priceBounds uses closes for lines and includes the baseline', () {
      final c = testCandles(2);
      final (lo, hi) = CandleGeometry.priceBounds(c, ChartType.line);
      expect(lo, lessThan(100));
      expect(hi, greaterThan(102));
      final (blo, _) = CandleGeometry.priceBounds(
        c,
        ChartType.candles,
        baseline: 50,
      );
      expect(blo, lessThan(50));
    });
    test(
      'log price axis gives equal percentage moves equal pixel distances',
      () {
        const low = 100.0;
        const height = 400.0;
        final y100 = CandleGeometry.priceY(
          100,
          low,
          400,
          height,
          logarithmic: true,
        );
        final y110 = CandleGeometry.priceY(
          110,
          low,
          400,
          height,
          logarithmic: true,
        );
        final y121 = CandleGeometry.priceY(
          121,
          low,
          400,
          height,
          logarithmic: true,
        );
        expect((y110 - y100).abs(), closeTo((y121 - y110).abs(), 1));
        expect(
          CandleGeometry.priceY(110, -1, 400, height, logarithmic: true),
          isA<double>().having((value) => value.isFinite, 'finite', isTrue),
        );
      },
    );
    test('axisLabel: time within a day, dates, months past 400 days', () {
      final t = DateTime.utc(2026, 1, 5, 4, 30);
      expect(
        CandleGeometry.axisLabel(
          t,
          const Duration(hours: 6),
          CandleInterval.m5,
        ),
        contains(':'),
      );
      expect(
        CandleGeometry.axisLabel(t, const Duration(days: 5), CandleInterval.h1),
        contains('Jan'),
      );
      expect(
        CandleGeometry.axisLabel(
          t,
          const Duration(days: 30),
          CandleInterval.d1,
        ),
        contains('Jan'),
      );
      expect(
        CandleGeometry.axisLabel(
          t,
          const Duration(days: 900),
          CandleInterval.w1,
        ),
        'Jan 26',
      );
    });
  });
}
