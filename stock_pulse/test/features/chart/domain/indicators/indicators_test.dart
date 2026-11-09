import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/chart/domain/indicators/indicator.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_calculator.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

// 60-close increasing fixture; the closed-form reference values below make
// the seed and warm-up points visible without deriving expected values from
// the production implementation.
final _closes60 = [for (var close = 1; close <= 60; close++) close.toDouble()];

List<Candle> _candles(List<double> closes) => [
  for (var i = 0; i < closes.length; i++) candle(closes[i], i),
];

Candle candle(double value, int index) => Candle(
  start: DateTime.utc(2026, 11, 9, 4, index * 5),
  open: value,
  high: value,
  low: value,
  close: value,
  volume: 100,
);
void main() {
  test('SMA and EMA seed on period average', () {
    final candles = [for (var i = 1; i <= 5; i++) candle(i.toDouble(), i)];
    final sma = Indicator(const StudySpec(kind: StudyKind.sma, period: 3))
      ..build(candles);
    final ema = Indicator(const StudySpec(kind: StudyKind.ema, period: 3))
      ..build(candles);
    expect(sma.series.lines['value'], [null, null, 2, 3, 4]);
    expect(ema.series.lines['value'], [null, null, 2, 3, 4]);
  });

  test(
    'SMA(20) and EMA(9) match every reference point in 60-close fixture',
    () {
      final candles = _candles(_closes60);
      final sma = Indicator(const StudySpec(kind: StudyKind.sma, period: 20))
        ..build(candles);
      final ema = Indicator(const StudySpec(kind: StudyKind.ema, period: 9))
        ..build(candles);

      expect(sma.series.lines['value'], [
        for (var i = 0; i < 60; i++)
          if (i < 19) null else i - 8.5,
      ]);
      expect(ema.series.lines['value'], [
        for (var i = 0; i < 60; i++)
          if (i < 8) null else i - 3.0,
      ]);
    },
  );

  test('VWAP weights typical price and resets at the next IST open', () {
    Candle bar(
      DateTime start,
      double high,
      double low,
      double close,
      int volume,
    ) => Candle(
      start: start,
      open: close,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
    final candles = [
      bar(DateTime.utc(2026, 11, 9, 3, 45), 110, 90, 100, 10),
      bar(DateTime.utc(2026, 11, 9, 3, 50), 120, 100, 110, 20),
      bar(DateTime.utc(2026, 11, 9, 3, 55), 130, 110, 120, 30),
      bar(DateTime.utc(2026, 11, 10, 3, 45), 210, 190, 200, 10),
    ];
    final indicator = Indicator(const StudySpec(kind: StudyKind.vwap))
      ..build(candles);

    expect(indicator.series.lines['value']![2], closeTo(6800 / 60, 1e-10));
    expect(indicator.series.lines['value']![3], 200);
    expect(indicator.supportsInterval(CandleInterval.m5), isTrue);
    expect(indicator.supportsInterval(CandleInterval.d1), isFalse);
  });

  test('RSI uses Wilder smoothing and remains inside the 0 to 100 range', () {
    final closes = [
      100,
      102,
      101,
      103,
      102,
      104,
    ].map((v) => v.toDouble()).toList();
    final indicator = Indicator(const StudySpec(kind: StudyKind.rsi, period: 3))
      ..build(_candles(closes));
    final values = indicator.series.lines['value']!;

    expect(values.take(3), [null, null, null]);
    expect(values[3], closeTo(80, 1e-10));
    expect(values[4], closeTo(61.5384615385, 1e-8));
    expect(values[5], closeTo(77.2727272727, 1e-8));
    expect(values.whereType<double>().every((v) => v >= 0 && v <= 100), isTrue);
  });

  test(
    'Bollinger uses population deviation and MACD uses EMA signal seeding',
    () {
      final short = _candles([1, 2, 3, 4]);
      final bands = Indicator(
        const StudySpec(kind: StudyKind.bollinger, period: 3),
      )..build(short);
      expect(bands.series.lines['middle'], [null, null, 2, 3]);
      expect(bands.series.lines['upper']![2], closeTo(3.6329931619, 1e-8));
      expect(bands.series.lines['lower']![2], closeTo(.3670068381, 1e-8));

      final macd = Indicator(const StudySpec(kind: StudyKind.macd))
        ..build(_candles(_closes60));
      final line = macd.series.lines['line']!;
      final signal = macd.series.lines['signal']!;
      final histogram = macd.series.lines['histogram']!;
      expect(line.take(25).every((value) => value == null), isTrue);
      expect(line[25], closeTo(7, 1e-10));
      expect(signal.take(33).every((value) => value == null), isTrue);
      expect(signal[33], closeTo(7, 1e-10));
      expect(histogram[33], closeTo(0, 1e-10));
      expect(histogram.last, closeTo(0, 1e-8));
    },
  );

  test('a 200-period study on 120 candles reports insufficient data', () {
    final study = Indicator(const StudySpec(kind: StudyKind.sma, period: 200))
      ..build(_candles([for (var i = 0; i < 120; i++) i.toDouble()]));
    expect(study.series.notEnoughData, isTrue);
  });

  test('500-candle append and replacement write one point per line', () {
    final base = [
      for (var i = 0; i < 500; i++) candle(100 + (i % 9).toDouble(), i),
    ];
    for (final kind in StudyKind.values) {
      final indicator = Indicator(StudySpec(kind: kind))..build(base);
      final replacement = candle(120, 499);
      indicator.update(replacement, append: false);
      final replaced = Indicator(StudySpec(kind: kind))
        ..build([...base.take(499), replacement]);
      expect(indicator.series.lines, replaced.series.lines, reason: kind.name);
      expect(
        indicator.writtenIndices,
        indicator.series.lines.length,
        reason: kind.name,
      );

      final appended = Indicator(StudySpec(kind: kind))..build(base);
      final next = candle(121, 500);
      appended.update(next, append: true);
      final rebuilt = Indicator(StudySpec(kind: kind))..build([...base, next]);
      expect(appended.series.lines, rebuilt.series.lines, reason: kind.name);
      expect(
        appended.writtenIndices,
        appended.series.lines.length,
        reason: '${kind.name} append',
      );
    }
  });

  test('RSI stays bounded; flat is neutral; VWAP is volume weighted', () {
    final rsi = Indicator(const StudySpec(kind: StudyKind.rsi, period: 3))
      ..build([for (var i = 0; i < 10; i++) candle(100, i)]);
    expect(rsi.series.lines['value']!.last, 50);
    final vwap = Indicator(const StudySpec(kind: StudyKind.vwap))
      ..build([candle(10, 0), candle(20, 1), candle(30, 2)]);
    expect(vwap.series.lines['value']!.last, 20);
  });

  test('StudyCalculator reuses identical inputs and updates changed tail', () {
    final calculator = StudyCalculator();
    final specs = [
      const StudySpec(kind: StudyKind.sma, period: 20),
      const StudySpec(kind: StudyKind.rsi),
    ];
    final initial = _candles(_closes60);
    final first = calculator.calculate(initial, specs);
    expect(identical(calculator.calculate(initial, specs), first), isTrue);

    final updated = [...initial]..[59] = candle(80, 59);
    final next = calculator.calculate(updated, specs);
    for (final spec in specs) {
      final fresh = Indicator(spec)..build(updated);
      expect(next[spec]!.lines, fresh.series.lines, reason: spec.kind.name);
    }
  });
}
