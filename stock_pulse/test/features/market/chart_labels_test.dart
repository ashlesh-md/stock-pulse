import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/l10n/locales/en/market_strings_en.dart';
import 'package:stock_pulse/features/chart/presentation/chart_labels.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

void main() {
  test('chart labels cover every type and interval', () {
    const strings = MarketStringsEn();
    expect(
      ChartType.values.map((type) => chartTypeLabel(strings, type)).toSet(),
      hasLength(5),
    );
    expect(ChartType.values.map(chartTypeIcon).toSet(), hasLength(5));
    expect(
      intervalOptionLabel(strings, CandleInterval.m1),
      '1m  ·  1 candle = 1 minute',
    );
    expect(
      CandleInterval.values
          .map((interval) => intervalOptionLabel(strings, interval))
          .toSet(),
      hasLength(6),
    );
  });
}
