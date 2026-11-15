import 'package:stock_pulse/core/l10n/locales/en/order_strings_en.dart';
import 'package:stock_pulse/core/l10n/locales/pseudo/pseudo_text.dart';
import 'package:stock_pulse/core/l10n/strings/order_strings.dart';

final class OrderStringsPseudo implements OrderStrings {
  const OrderStringsPseudo();

  static const _en = OrderStringsEn();

  @override
  String get buy => pseudo(_en.buy);
  @override
  String get blockUnavailable => pseudo(_en.blockUnavailable);
  @override
  String get blockClosed => pseudo(_en.blockClosed);
  @override
  String get blockPreOpen => pseudo(_en.blockPreOpen);
  @override
  String get blockTrigger => pseudo(_en.blockTrigger);
  @override
  String get blockProduct => pseudo(_en.blockProduct);
  @override
  String get blockExpired => pseudo(_en.blockExpired);
  @override
  String get blockCutoff => pseudo(_en.blockCutoff);
  @override
  String get blockRisk => pseudo(_en.blockRisk);
  @override
  String get blockFunds => pseudo(_en.blockFunds);
  @override
  String fundsAvailable(String amount) => pseudo(_en.fundsAvailable(amount));
  @override
  String get marginNotSimulated => pseudo(_en.marginNotSimulated);
  @override
  String get nudgeLimitFar => pseudo(_en.nudgeLimitFar);
  @override
  String nudgeLargeOrder(String percent) =>
      pseudo(_en.nudgeLargeOrder(percent));
  @override
  String get nudgeExpiryToday => pseudo(_en.nudgeExpiryToday);
  @override
  String get nudgeUnderlyingStale => pseudo(_en.nudgeUnderlyingStale);
  @override
  String get riskTitle => pseudo(_en.riskTitle);
  @override
  String get riskBody => pseudo(_en.riskBody);
  @override
  String get riskAgree => pseudo(_en.riskAgree);
  @override
  String get riskContinue => pseudo(_en.riskContinue);
  @override
  String get pendingPrevious => pseudo(_en.pendingPrevious);
  @override
  String get statusPending => pseudo(_en.statusPending);
  @override
  String get submitting => pseudo(_en.submitting);
  @override
  String get placing => pseudo(_en.placing);
  @override
  String get checkingStatus => pseudo(_en.checkingStatus);
  @override
  String get orderStatusUnknown => pseudo(_en.orderStatusUnknown);
  @override
  String get viewOrders => pseudo(_en.viewOrders);
  @override
  String get refreshStatus => pseudo(_en.refreshStatus);
  @override
  String get waitingForConnection => pseudo(_en.waitingForConnection);
  @override
  String get stopLoss => pseudo(_en.stopLoss);
  @override
  String get triggerPrice => pseudo(_en.triggerPrice);
  @override
  String get stopLossHint => pseudo(_en.stopLossHint);
  @override
  String get product => pseudo(_en.product);
  @override
  String get delivery => pseudo(_en.delivery);
  @override
  String get intraday => pseudo(_en.intraday);
  @override
  String get carryForward => pseudo(_en.carryForward);
  @override
  String get estimatedValue => pseudo(_en.estimatedValue);
  @override
  String get charges => pseudo(_en.charges);
  @override
  String get chargesHint => pseudo(_en.chargesHint);
  @override
  String get margin => pseudo(_en.margin);
  @override
  String get sell => pseudo(_en.sell);
  @override
  String get market => pseudo(_en.market);
  @override
  String get limit => pseudo(_en.limit);
  @override
  String get quantity => pseudo(_en.quantity);
  @override
  String get limitPrice => pseudo(_en.limitPrice);
  @override
  String get rupeePrefix => pseudo(_en.rupeePrefix);
  @override
  String get quantityInvalid => pseudo(_en.quantityInvalid);
  @override
  String get priceInvalid => pseudo(_en.priceInvalid);
  @override
  String get limitHintBuy => pseudo(_en.limitHintBuy);
  @override
  String get limitHintSell => pseudo(_en.limitHintSell);
  @override
  String get marketHintBuy => pseudo(_en.marketHintBuy);
  @override
  String get marketHintSell => pseudo(_en.marketHintSell);
  @override
  String get strategyTitle => pseudo(_en.strategyTitle);
  @override
  String get payoffPreview => pseudo(_en.payoffPreview);
  @override
  String sheetTitle(String symbol, String ltp) =>
      pseudo(_en.sheetTitle(symbol, ltp));
  @override
  String ticketTitle(String symbol) => pseudo(_en.ticketTitle(symbol));
  @override
  String get orderType => pseudo(_en.orderType);
  @override
  String get lotsLabel => pseudo(_en.lotsLabel);
  @override
  String get priceTick => pseudo(_en.priceTick);
  @override
  String get triggerInvalid => pseudo(_en.triggerInvalid);
  @override
  String get fixFields => pseudo(_en.fixFields);
  @override
  String lotSizeLine(int lotSize) => pseudo(_en.lotSizeLine(lotSize));
  @override
  String unitsTotal(int quantity, String value) =>
      pseudo(_en.unitsTotal(quantity, value));
  @override
  String confirmLabel(String side, String amount, String symbol) =>
      pseudo(_en.confirmLabel(side, amount, symbol));
  @override
  String notPlaced(String reason) => pseudo(_en.notPlaced(reason));
  @override
  String get rejectedPriceBand => pseudo(_en.rejectedPriceBand);
  @override
  String get rejectedHoldings => pseudo(_en.rejectedHoldings);
  @override
  String get rejectedFunds => pseudo(_en.rejectedFunds);
  @override
  String get rejectedQuantity => pseudo(_en.rejectedQuantity);
  @override
  String get rejectedPrice => pseudo(_en.rejectedPrice);
  @override
  String get rejectedSymbol => pseudo(_en.rejectedSymbol);
  @override
  String get rejectedInvalid => pseudo(_en.rejectedInvalid);
  @override
  String what(String side, int quantity, String symbol) =>
      pseudo(_en.what(side, quantity, symbol));
  @override
  String filled(String what, String price) => pseudo(_en.filled(what, price));
  @override
  String waiting(String what, String price) => pseudo(_en.waiting(what, price));
  @override
  String cancelled(String what) => pseudo(_en.cancelled(what));
  @override
  String rejected(String what) => pseudo(_en.rejected(what));
  @override
  String rejectedBecause(String what, String reason) =>
      pseudo(_en.rejectedBecause(what, reason));
  @override
  String withId(String orderId, String summary) =>
      pseudo(_en.withId(orderId, summary));
}
