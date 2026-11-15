import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

@immutable
class ChartPrefs {
  const ChartPrefs({
    this.range = ChartRange.d1,
    this.interval = CandleInterval.m5,
    this.type = ChartType.candles,
    this.logScale = false,
    this.gridlines = true,
  });

  final ChartRange range;
  final CandleInterval interval;
  final ChartType type;
  final bool logScale;
  final bool gridlines;

  ChartPrefs copyWith({
    ChartRange? range,
    CandleInterval? interval,
    ChartType? type,
    bool? logScale,
    bool? gridlines,
  }) => ChartPrefs(
    range: range ?? this.range,
    interval: interval ?? this.interval,
    type: type ?? this.type,
    logScale: logScale ?? this.logScale,
    gridlines: gridlines ?? this.gridlines,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': 1,
    'range': range.name,
    'interval': interval.name,
    'type': type.name,
    'logScale': logScale,
    'gridlines': gridlines,
  };

  factory ChartPrefs.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported chart preferences version');
    }
    return ChartPrefs(
      range: ChartRange.values.byName(json['range']! as String),
      interval: CandleInterval.values.byName(json['interval']! as String),
      type: ChartType.values.byName(json['type']! as String),
      logScale: json['logScale']! as bool,
      gridlines: json['gridlines']! as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChartPrefs &&
      other.range == range &&
      other.interval == interval &&
      other.type == type &&
      other.logScale == logScale &&
      other.gridlines == gridlines;

  @override
  int get hashCode => Object.hash(range, interval, type, logScale, gridlines);
}
