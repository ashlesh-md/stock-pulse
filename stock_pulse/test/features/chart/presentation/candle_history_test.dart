import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/l10n/locales/en/market_strings_en.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/features/chart/presentation/candle_history_painter.dart';
import 'package:stock_pulse/features/chart/presentation/candle_painter.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

void main() {
  final candles = [
    for (var i = 0; i < 12; i++)
      Candle(
        start: DateTime.utc(2026, 11, 12, 4, i * 5),
        open: 100,
        high: 120,
        low: 80,
        close: 100,
        volume: 100,
      ),
  ];
  CandleHistoryPainter painter(List<Candle> values) => CandleHistoryPainter(
    CandlePainter(
      candles: values,
      type: ChartType.candles,
      interval: CandleInterval.m5,
      baseline: null,
      candleWidth: 10,
      offset: 0,
      crosshair: null,
      gridColor: Colors.grey,
      textStyle: const TextStyle(color: Colors.white),
      labelBackground: Colors.black,
      colors: SpColors.dark,
      strings: const MarketStringsEn(),
      historyOnly: true,
    ),
    const Size(300, 200),
  );
  test(
    'S-53 a last-candle tick leaves the historical paint layer unchanged',
    () {
      final old = painter(candles);
      final next = painter([
        ...candles.take(11),
        candles.last.copyWith(close: 105),
      ]);
      expect(next.shouldRepaint(old), isFalse);
      expect(
        painter([...candles.take(11), candles.last.copyWith(high: 130)])
            .shouldRepaint(old),
        isTrue,
      );
      expect(
        painter([candles.first.copyWith(close: 110), ...candles.skip(1)])
            .shouldRepaint(old),
        isTrue,
      );
    },
  );
}
