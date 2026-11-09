class StrategyStrings {
  const StrategyStrings();
  String get empty => 'Add legs from the option chain';
  String get openChain => 'Open option chain';
  String get failed => 'Could not price legs. Retry';
  String get preview => 'Preview only · each leg trades alone';
  String get todayUnavailable => 'Today line needs live prices';
  String get unlimited => 'Unlimited';
  String maxProfitValue(String amount) => 'Max profit: $amount';
  String maxLossValue(String amount) => 'Max loss: $amount';
  String breakevensValue(List<String> prices) =>
      'Breakevens: ${prices.join(' / ')}';
  String netPremiumValue(String amount) => 'Net premium: $amount';
  String get trade => 'Trade';
  String get remove => 'Remove leg';
  String get chart => 'Payoff at expiry';
  String legs(int count) => 'Legs ($count/4)';
  String crosshair(String spot, String value) => 'Spot $spot · P&L $value';
}
