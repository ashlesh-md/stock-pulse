import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/domain/chart_state.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

void main() {
  test('crosshair can be cleared while other chart settings are preserved', () {
    final selected = ChartState(
      range: ChartRange.w1,
      interval: CandleInterval.m15,
      type: ChartType.line,
    ).copyWith(crosshairIndex: 10);

    final cleared = selected.copyWith(crosshairIndex: null);
    expect(cleared.crosshairIndex, isNull);
    expect(cleared.range, ChartRange.w1);
    expect(cleared.interval, CandleInterval.m15);
    expect(cleared.type, ChartType.line);
  });
}
