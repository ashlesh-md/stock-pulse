import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/domain/fib_levels.dart';
import 'package:stock_pulse/features/chart/domain/indicators/indicator.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_calculator.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

Candle _c(int i) => Candle(
  start: DateTime.utc(2026).add(Duration(minutes: i)),
  open: 100.0 + i,
  high: 101.0 + i,
  low: 99.0 + i,
  close: 100.5 + i,
  volume: 10,
);

void main() {
  test('a study spec round-trips through JSON', () {
    const spec = StudySpec(kind: StudyKind.macd, fast: 5, slow: 9, signal: 3);
    expect(StudySpec.fromJson(spec.toJson()), spec);
  });

  test('an invalid spec is rejected', () {
    for (final bad in [
      const StudySpec(kind: StudyKind.sma, period: 0),
      const StudySpec(kind: StudyKind.macd, fast: 9, slow: 9),
      const StudySpec(kind: StudyKind.bollinger, deviations: double.nan),
      const StudySpec(kind: StudyKind.bollinger, deviations: 0),
    ]) {
      expect(() => Indicator(bad), throwsArgumentError);
    }
  });

  test('one appended candle extends the series without a full recompute', () {
    final calc = StudyCalculator();
    const spec = StudySpec(kind: StudyKind.sma, period: 3);
    final base = [for (var i = 0; i < 10; i++) _c(i)];
    final first = calc.calculate(base, const [spec])[spec]!;
    final grown = [...base, _c(10)];
    final next = calc.calculate(grown, const [spec])[spec]!;
    final fresh = StudyCalculator().calculate(grown, const [spec])[spec]!;
    expect(next.lines.values.first.length, first.lines.values.first.length + 1);
    expect(next.lines.values.first, fresh.lines.values.first);
  });

  test('adding a study on the same candles reuses the existing series', () {
    final calc = StudyCalculator();
    const sma = StudySpec(kind: StudyKind.sma, period: 3);
    const ema = StudySpec(kind: StudyKind.ema, period: 3);
    final candles = [for (var i = 0; i < 6; i++) _c(i)];
    final first = calc.calculate(candles, const [sma])[sma]!;
    final both = calc.calculate(candles, const [sma, ema]);
    expect(both[sma]!.lines, first.lines);
    expect(both[ema], isNotNull);
  });

  test('fib levels label their ratio and compare by value', () {
    final levels = fibLevels(0, 10);
    expect(levels[1].label, '23.6%');
    expect(levels.first, const FibLevel(ratio: 0, price: 0));
    expect(levels.first.hashCode, const FibLevel(ratio: 0, price: 0).hashCode);
  });
}
