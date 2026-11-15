import 'package:stock_pulse/features/market/domain/candle.dart';

/// Initial chart settings carried by a stock route.
class ChartSelection {
  const ChartSelection({
    required this.range,
    required this.interval,
    this.type,
  });

  final ChartRange range;
  final CandleInterval interval;
  final ChartType? type;

  static ChartSelection fromQuery(Map<String, String> query) {
    final range = ChartRange.values.firstWhere(
      (value) => value.label == query['range'],
      orElse: () => ChartRange.d1,
    );
    final interval = range.intervals.firstWhere(
      (value) => value.apiName == query['interval'],
      orElse: () => range.defaultInterval,
    );
    return ChartSelection(
      range: range,
      interval: interval,
      type: ChartType.values.asNameMap()[query['type']],
    );
  }

  // Value equality: the route scope rebuilds this on every navigation, and a
  // new but equal selection must not recreate the chart controllers.
  @override
  bool operator ==(Object other) =>
      other is ChartSelection &&
      other.range == range &&
      other.interval == interval &&
      other.type == type;

  @override
  int get hashCode => Object.hash(range, interval, type);
}
