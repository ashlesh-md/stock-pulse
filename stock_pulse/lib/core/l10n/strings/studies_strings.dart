class StudiesStrings {
  const StudiesStrings();
  String get undo => 'Undo';
  String get removed => 'Study removed';
  String get title => 'Studies';
  String get limit => 'You can use up to 4 studies. Remove one to add another.';
  String get paneLimit => 'You can use up to 2 lower panes.';
  String get add => 'Add study';
  String periodValue(int period) => 'Period: $period';
  String get intradayOnly => 'VWAP: intraday only';
  String get remove => 'Remove study';
  String notEnough(String name) => 'Not enough data for $name';
  String name(String kind) => switch (kind) {
    'sma' => 'SMA',
    'ema' => 'EMA',
    'vwap' => 'VWAP',
    'rsi' => 'RSI',
    'bollinger' => 'Bollinger Bands',
    'macd' => 'MACD',
    _ => kind.toUpperCase(),
  };
}
