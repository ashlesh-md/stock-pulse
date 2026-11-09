import 'package:stock_pulse/core/l10n/strings/portfolio_strings.dart';

final class PortfolioStringsEn implements PortfolioStrings {
  const PortfolioStringsEn();

  @override
  String get positions => 'Positions';
  @override
  String get holdings => 'Holdings';
  @override
  String get orders => 'Orders';
  @override
  String get noHoldings => 'No delivery holdings yet.';
  @override
  String get buyMore => 'Buy more';
  @override
  String get exit => 'Exit';
  @override
  String get averagePrice => 'Average price';
  @override
  String get quantity => 'Quantity';

  @override
  String get title => 'Portfolio';
  @override
  String positionsHeader(int n) => 'Positions ($n)';
  @override
  String ordersHeader(int n) => 'Orders ($n)';
  @override
  String get noPositions =>
      'No positions yet. Buy something from the watchlist.';
  @override
  String get goToWatchlist => 'Go to watchlist';
  @override
  String get unrealisedLive => 'Unrealised P&L (live)';
  @override
  String get realised => 'Realised P&L';
  @override
  String get lastPrice => 'LTP';
  @override
  String get invested => 'Invested';
  @override
  String get currentValue => 'Current value';
  @override
  String get dayPnl => 'Day P&L';
  @override
  String get totalPnl => 'Total P&L';
  @override
  String fundsAvailable(String amount) => 'Funds available · $amount';
  @override
  String get holdingsFailed =>
      'Holdings could not be loaded. Check the connection and try again.';
  @override
  String get noOrders => 'No orders today';
  @override
  String pnlPercent(String pnl, String percent) => '$pnl ($percent)';
  @override
  String closedRealised(String pnl) => 'Closed · realised $pnl';
  @override
  String longPosition(int quantity, String average) =>
      'Long $quantity @ $average';
  @override
  String shortPosition(int quantity, String average) =>
      'Short $quantity @ $average';
  @override
  String ltp(String price) => 'LTP $price';
  @override
  String atPrice(String price) => '@ $price';
  @override
  String limitAt(String price) => 'limit $price';
  @override
  String get marketPrice => 'market';
  @override
  String orderTitle(String symbol, int quantity, String price) =>
      '$symbol × $quantity  $price';
  @override
  String orderSubtitle(String orderId, String type, String time) =>
      '$orderId · $type · $time';
  @override
  String get cancel => 'Cancel';
  @override
  String get cancelFailed => 'Could not cancel the order. Try again.';
  @override
  String get statusOpen => 'open';
  @override
  String get statusQueued => 'queued';

  @override
  String get statusPending => 'Pending';

  @override
  String get refreshStatus => 'Refresh status';

  @override
  String get waitingForConnection => 'Waiting for connection';
  @override
  String get statusTriggerPending => 'trigger pending';
  @override
  String get statusComplete => 'complete';
  @override
  String get statusCancelled => 'cancelled';
  @override
  String get statusRejected => 'rejected';
}
