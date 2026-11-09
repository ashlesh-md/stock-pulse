import 'package:stock_pulse/features/market/domain/candle.dart';

final testT0 = DateTime.utc(2026, 11, 4, 4);

List<Candle> testCandles(
  int count, {
  Duration step = const Duration(minutes: 5),
}) => [
  for (var index = 0; index < count; index++)
    Candle(
      start: testT0.add(step * index),
      open: 100.0 + index,
      high: 103.0 + index,
      low: 98.0 + index,
      close: index.isEven ? 102.0 + index : 99.0 + index,
      volume: 1000 + index,
    ),
];
