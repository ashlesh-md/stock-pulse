/// Watchlist and stock page.
abstract interface class MarketStrings {
  String get watchlistTitle;
  String get pinFavourite;
  String get unpinFavourite;
  String get reorder;
  String get editWatchlist;
  String get rowActionsTitle;
  String get openChart;
  String get openOptionChain;
  String get setAlert;
  String advancing(int n);
  String declining(int n);
  String instrumentSubtitle(String exchange, String name);

  String instrumentLine(String name, String exchange, String sector);
  String lastTrade(String time);
  String rangePerformance(String range, String percent, String change);
  String rangeHighLow(String high, String low);

  String get intervalTooltip;
  String intervalOption(String code, String unit);
  String get unitMinute;
  String get unitFiveMinutes;
  String get unitFifteenMinutes;
  String get unitHour;
  String get unitDay;
  String get unitWeek;

  String get chartTypeTooltip;
  String get chartCandles;
  String get chartHeikinAshi;
  String get chartOhlc;
  String get chartLine;
  String get chartArea;
  String get chartLoadFailed;

  String crosshairClose(String close);
  String crosshairOhlc(String open, String high, String low, String close);
  String crosshairLine(String when, String values, String volume);

  String get statOpen;
  String get statHigh;
  String get statLow;
  String get statPrevClose;
  String get statVolume;
  String get statLastQty;
  String get statBid;
  String get statAsk;
  String get statSpread;

  String get marketDepth;
  String get depthBid;
  String get depthAsk;
  String get depthOrders;
  String get depthQuantity;
  String get depthTotal;
}
