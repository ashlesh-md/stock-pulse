import 'package:stock_pulse/core/l10n/strings/market_strings.dart';

final class MarketStringsEn implements MarketStrings {
  const MarketStringsEn();

  @override
  String get pinFavourite => 'Pin favourite';
  @override
  String get unpinFavourite => 'Unpin favourite';
  @override
  String get reorder => 'Drag to reorder';
  @override
  String get editWatchlist => 'Edit';
  @override
  String get rowActionsTitle => 'Stock actions';
  @override
  String get openChart => 'Chart';
  @override
  String get openOptionChain => 'Option chain';
  @override
  String get setAlert => 'Set alert';

  @override
  String get watchlistTitle => 'Watchlist';
  @override
  String advancing(int n) => '▲ $n advancing';
  @override
  String declining(int n) => '▼ $n declining';
  @override
  String instrumentSubtitle(String exchange, String name) =>
      '$exchange · $name';

  @override
  String instrumentLine(String name, String exchange, String sector) =>
      '$name · $exchange · $sector';
  @override
  String lastTrade(String time) => 'Last trade $time';
  @override
  String rangePerformance(String range, String percent, String change) =>
      '$range  $percent ($change)';
  @override
  String rangeHighLow(String high, String low) => 'H $high   L $low';

  @override
  String get intervalTooltip => 'Candle interval';
  @override
  String intervalOption(String code, String unit) =>
      '$code  ·  1 candle = 1 $unit';
  @override
  String get unitMinute => 'minute';
  @override
  String get unitFiveMinutes => '5 minutes';
  @override
  String get unitFifteenMinutes => '15 minutes';
  @override
  String get unitHour => 'hour';
  @override
  String get unitDay => 'day';
  @override
  String get unitWeek => 'week';

  @override
  String get chartTypeTooltip => 'Chart type';
  @override
  String get chartCandles => 'Candles';
  @override
  String get chartHeikinAshi => 'Heikin-Ashi';
  @override
  String get chartOhlc => 'OHLC bars';
  @override
  String get chartLine => 'Line';
  @override
  String get chartArea => 'Area';
  @override
  String get chartLoadFailed => 'Could not load this chart. Pick it again.';

  @override
  String crosshairClose(String close) => 'Close $close';
  @override
  String crosshairOhlc(String open, String high, String low, String close) =>
      'O $open  H $high  L $low  C $close';
  @override
  String crosshairLine(String when, String values, String volume) =>
      '$when  $values  V $volume';

  @override
  String get statOpen => 'Open';
  @override
  String get statHigh => 'High';
  @override
  String get statLow => 'Low';
  @override
  String get statPrevClose => 'Prev close';
  @override
  String get statVolume => 'Volume';
  @override
  String get statLastQty => 'Last qty';
  @override
  String get statBid => 'Bid';
  @override
  String get statAsk => 'Ask';
  @override
  String get statSpread => 'Spread';

  @override
  String get marketDepth => 'Market depth';
  @override
  String get depthBid => 'Bid';
  @override
  String get depthAsk => 'Ask';
  @override
  String get depthOrders => 'Orders';
  @override
  String get depthQuantity => 'Qty';
  @override
  String get depthTotal => 'Total';
}
