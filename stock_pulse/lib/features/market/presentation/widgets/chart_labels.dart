import 'package:flutter/widgets.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/strings/market_strings.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

String chartTypeLabel(MarketStrings s, ChartType t) => switch (t) {
  ChartType.candles => s.chartCandles,
  ChartType.heikinAshi => s.chartHeikinAshi,
  ChartType.ohlc => s.chartOhlc,
  ChartType.line => s.chartLine,
  ChartType.area => s.chartArea,
};

IconData chartTypeIcon(ChartType t) => switch (t) {
  ChartType.candles => AppIcons.chartCandles,
  ChartType.heikinAshi => AppIcons.chartHeikinAshi,
  ChartType.ohlc => AppIcons.chartOhlc,
  ChartType.line => AppIcons.chartLine,
  ChartType.area => AppIcons.chartArea,
};

/// `5m  ·  1 candle = 1 5 minutes` style menu row.
String intervalOptionLabel(MarketStrings s, CandleInterval i) =>
    s.intervalOption(i.apiName, switch (i) {
      CandleInterval.m1 => s.unitMinute,
      CandleInterval.m5 => s.unitFiveMinutes,
      CandleInterval.m15 => s.unitFifteenMinutes,
      CandleInterval.h1 => s.unitHour,
      CandleInterval.d1 => s.unitDay,
      CandleInterval.w1 => s.unitWeek,
    });
