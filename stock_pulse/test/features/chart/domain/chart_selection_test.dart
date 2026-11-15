import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/domain/chart_selection.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

void main() {
  test('equal selections compare equal so a route rebuild keeps the chart', () {
    final a = ChartSelection.fromQuery({'range': '1W', 'interval': '15m'});
    final b = ChartSelection.fromQuery({'range': '1W', 'interval': '15m'});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(b.withType(ChartType.line)));
    expect(
      a,
      isNot(
        const ChartSelection(range: ChartRange.d1, interval: CandleInterval.m5),
      ),
    );
    expect(a == Object(), isFalse);
  });
}

extension on ChartSelection {
  ChartSelection withType(ChartType type) =>
      ChartSelection(range: range, interval: interval, type: type);
}
