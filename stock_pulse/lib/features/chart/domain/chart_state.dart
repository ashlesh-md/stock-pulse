import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/chart/domain/chart_layout.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

const _keepCrosshair = Object();

/// Chart-specific user state derived from the stock's candle feed.
@immutable
class ChartState {
  ChartState({
    required this.range,
    required this.interval,
    required this.type,
    this.crosshairIndex,
    this.logScale = false,
    this.gridlines = true,
    ChartLayout? layout,
  }) : layout = layout ?? ChartLayout();

  final ChartRange range;
  final CandleInterval interval;
  final ChartType type;
  final int? crosshairIndex;
  final bool logScale;
  final bool gridlines;
  final ChartLayout layout;

  ChartState copyWith({
    ChartRange? range,
    CandleInterval? interval,
    ChartType? type,
    Object? crosshairIndex = _keepCrosshair,
    ChartLayout? layout,
    bool? logScale,
    bool? gridlines,
  }) => ChartState(
    range: range ?? this.range,
    interval: interval ?? this.interval,
    type: type ?? this.type,
    crosshairIndex: identical(crosshairIndex, _keepCrosshair)
        ? this.crosshairIndex
        : crosshairIndex as int?,
    layout: layout ?? this.layout,
    logScale: logScale ?? this.logScale,
    gridlines: gridlines ?? this.gridlines,
  );

  @override
  bool operator ==(Object other) =>
      other is ChartState &&
      other.range == range &&
      other.interval == interval &&
      other.type == type &&
      other.crosshairIndex == crosshairIndex &&
      other.logScale == logScale &&
      other.gridlines == gridlines &&
      other.layout == layout;

  @override
  int get hashCode => Object.hash(
    range,
    interval,
    type,
    crosshairIndex,
    layout,
    logScale,
    gridlines,
  );
}
