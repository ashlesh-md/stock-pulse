import 'package:stock_pulse/core/l10n/locales/en/portfolio_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/portfolio_strings.dart';

final class PortfolioStringsPseudo implements PortfolioStrings {
  const PortfolioStringsPseudo();

  static const _en = PortfolioStringsEn();

  @override
  String get title => pseudo(_en.title);
  @override
  String get positions => pseudo(_en.positions);
  @override
  String get holdings => pseudo(_en.holdings);
  @override
  String get orders => pseudo(_en.orders);
  @override
  String get noHoldings => pseudo(_en.noHoldings);
  @override
  String get buyMore => pseudo(_en.buyMore);
  @override
  String get exit => pseudo(_en.exit);
  @override
  String get averagePrice => pseudo(_en.averagePrice);
  @override
  String get quantity => pseudo(_en.quantity);
  @override
  String positionsHeader(int n) => pseudo(_en.positionsHeader(n));
  @override
  String ordersHeader(int n) => pseudo(_en.ordersHeader(n));
  @override
  String get noPositions => pseudo(_en.noPositions);
  @override
  String get unrealisedLive => pseudo(_en.unrealisedLive);
  @override
  String get realised => pseudo(_en.realised);
  @override
  String get lastPrice => pseudo(_en.lastPrice);
  @override
  String get invested => pseudo(_en.invested);
  @override
  String get currentValue => pseudo(_en.currentValue);
  @override
  String get dayPnl => pseudo(_en.dayPnl);
  @override
  String get totalPnl => pseudo(_en.totalPnl);
  @override
  String fundsAvailable(String amount) => pseudo(_en.fundsAvailable(amount));
  @override
  String get holdingsFailed => pseudo(_en.holdingsFailed);
  @override
  String get noOrders => pseudo(_en.noOrders);
  @override
  String get goToWatchlist => pseudo(_en.goToWatchlist);
  @override
  String pnlPercent(String pnl, String percent) =>
      pseudo(_en.pnlPercent(pnl, percent));
  @override
  String closedRealised(String pnl) => pseudo(_en.closedRealised(pnl));
  @override
  String longPosition(int quantity, String average) =>
      pseudo(_en.longPosition(quantity, average));
  @override
  String shortPosition(int quantity, String average) =>
      pseudo(_en.shortPosition(quantity, average));
  @override
  String ltp(String price) => pseudo(_en.ltp(price));
  @override
  String atPrice(String price) => pseudo(_en.atPrice(price));
  @override
  String limitAt(String price) => pseudo(_en.limitAt(price));
  @override
  String get marketPrice => pseudo(_en.marketPrice);
  @override
  String orderTitle(String symbol, int quantity, String price) =>
      pseudo(_en.orderTitle(symbol, quantity, price));
  @override
  String orderSubtitle(String orderId, String type, String time) =>
      pseudo(_en.orderSubtitle(orderId, type, time));
  @override
  String get cancel => pseudo(_en.cancel);
  @override
  String get cancelFailed => pseudo(_en.cancelFailed);
  @override
  String get statusOpen => pseudo(_en.statusOpen);
  @override
  String get statusQueued => pseudo(_en.statusQueued);
  @override
  String get statusPending => pseudo(_en.statusPending);
  @override
  String get refreshStatus => pseudo(_en.refreshStatus);
  @override
  String get waitingForConnection => pseudo(_en.waitingForConnection);
  @override
  String get statusTriggerPending => pseudo(_en.statusTriggerPending);
  @override
  String get statusComplete => pseudo(_en.statusComplete);
  @override
  String get statusCancelled => pseudo(_en.statusCancelled);
  @override
  String get statusRejected => pseudo(_en.statusRejected);
}
