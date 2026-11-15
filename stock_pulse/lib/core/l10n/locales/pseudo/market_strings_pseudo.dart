import 'package:stock_pulse/core/l10n/locales/en/market_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/market_strings.dart';

final class MarketStringsPseudo implements MarketStrings {
  const MarketStringsPseudo();

  static const _en = MarketStringsEn();

  @override
  String get watchlistTitle => pseudo(_en.watchlistTitle);
  @override
  String get pinFavourite => pseudo(_en.pinFavourite);
  @override
  String get unpinFavourite => pseudo(_en.unpinFavourite);
  @override
  String get reorder => pseudo(_en.reorder);
  @override
  String get editWatchlist => pseudo(_en.editWatchlist);
  @override
  String get rowActionsTitle => pseudo(_en.rowActionsTitle);
  @override
  String get openChart => pseudo(_en.openChart);
  @override
  String get openOptionChain => pseudo(_en.openOptionChain);
  @override
  String get setAlert => pseudo(_en.setAlert);
  @override
  String advancing(int n) => pseudo(_en.advancing(n));
  @override
  String declining(int n) => pseudo(_en.declining(n));
  @override
  String instrumentSubtitle(String exchange, String name) =>
      pseudo(_en.instrumentSubtitle(exchange, name));
  @override
  String instrumentLine(String name, String exchange, String sector) =>
      pseudo(_en.instrumentLine(name, exchange, sector));
  @override
  String lastTrade(String time) => pseudo(_en.lastTrade(time));
  @override
  String rangePerformance(String range, String percent, String change) =>
      pseudo(_en.rangePerformance(range, percent, change));
  @override
  String rangeHighLow(String high, String low) =>
      pseudo(_en.rangeHighLow(high, low));
  @override
  String get intervalTooltip => pseudo(_en.intervalTooltip);
  @override
  String intervalOption(String code, String unit) =>
      pseudo(_en.intervalOption(code, unit));
  @override
  String get unitMinute => pseudo(_en.unitMinute);
  @override
  String get unitFiveMinutes => pseudo(_en.unitFiveMinutes);
  @override
  String get unitFifteenMinutes => pseudo(_en.unitFifteenMinutes);
  @override
  String get unitHour => pseudo(_en.unitHour);
  @override
  String get unitDay => pseudo(_en.unitDay);
  @override
  String get unitWeek => pseudo(_en.unitWeek);
  @override
  String get chartTypeTooltip => pseudo(_en.chartTypeTooltip);
  @override
  String get chartCandles => pseudo(_en.chartCandles);
  @override
  String get chartHeikinAshi => pseudo(_en.chartHeikinAshi);
  @override
  String get chartOhlc => pseudo(_en.chartOhlc);
  @override
  String get chartLine => pseudo(_en.chartLine);
  @override
  String get chartArea => pseudo(_en.chartArea);
  @override
  String get chartLoadFailed => pseudo(_en.chartLoadFailed);
  @override
  String get chartNoCandles => pseudo(_en.chartNoCandles);
  @override
  String get chartPreviousSession => pseudo(_en.chartPreviousSession);
  @override
  String crosshairClose(String close) => pseudo(_en.crosshairClose(close));
  @override
  String crosshairOhlc(String open, String high, String low, String close) =>
      pseudo(_en.crosshairOhlc(open, high, low, close));
  @override
  String crosshairLine(String when, String values, String volume) =>
      pseudo(_en.crosshairLine(when, values, volume));
  @override
  String get statOpen => pseudo(_en.statOpen);
  @override
  String get statHigh => pseudo(_en.statHigh);
  @override
  String get statLow => pseudo(_en.statLow);
  @override
  String get statPrevClose => pseudo(_en.statPrevClose);
  @override
  String get statVolume => pseudo(_en.statVolume);
  @override
  String get statLastQty => pseudo(_en.statLastQty);
  @override
  String get statBid => pseudo(_en.statBid);
  @override
  String get statAsk => pseudo(_en.statAsk);
  @override
  String get statSpread => pseudo(_en.statSpread);
  @override
  String get marketDepth => pseudo(_en.marketDepth);
  @override
  String get depthBid => pseudo(_en.depthBid);
  @override
  String get depthAsk => pseudo(_en.depthAsk);
  @override
  String get depthOrders => pseudo(_en.depthOrders);
  @override
  String get depthQuantity => pseudo(_en.depthQuantity);
  @override
  String get depthTotal => pseudo(_en.depthTotal);
}
