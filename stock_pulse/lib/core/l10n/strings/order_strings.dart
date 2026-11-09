import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/l10n/strings/error_strings.dart';

/// Order sheet and order outcome texts.
abstract interface class OrderStrings {
  String get buy;
  String get blockUnavailable;
  String get blockClosed;
  String get blockPreOpen;
  String get blockTrigger;
  String get blockProduct;
  String get blockExpired;
  String get blockCutoff;
  String get blockRisk;
  String get blockFunds;
  String fundsAvailable(String amount);
  String get marginNotSimulated;
  String get nudgeLimitFar;
  String nudgeLargeOrder(String percent);
  String get nudgeExpiryToday;
  String get nudgeUnderlyingStale;
  String get riskTitle;
  String get riskBody;
  String get riskAgree;
  String get riskContinue;
  String get pendingPrevious;
  String get statusPending;
  String get submitting;
  String get placing;
  String get checkingStatus;
  String get orderStatusUnknown;
  String get viewOrders;
  String get refreshStatus;
  String get waitingForConnection;
  String get stopLoss;
  String get triggerPrice;
  String get stopLossHint;
  String get product;
  String get delivery;
  String get intraday;
  String get carryForward;
  String get estimatedValue;
  String get charges;
  String get chargesHint;
  String get margin;
  String get sell;
  String get market;
  String get limit;
  String get quantity;
  String get limitPrice;
  String get rupeePrefix;
  String get quantityInvalid;
  String get priceInvalid;
  String get limitHintBuy;
  String get limitHintSell;
  String get marketHintBuy;
  String get marketHintSell;
  String get strategyTitle;
  String get payoffPreview;
  String sheetTitle(String symbol, String ltp);
  String ticketTitle(String symbol);
  String get orderType;
  String get lotsLabel;
  String get priceTick;
  String get triggerInvalid;
  String get fixFields;
  String lotSizeLine(int lotSize);
  String unitsTotal(int quantity, String value);
  String confirmLabel(String side, String amount, String symbol);
  String notPlaced(String reason);
  String get rejectedPriceBand;
  String get rejectedHoldings;
  String get rejectedFunds;
  String get rejectedQuantity;
  String get rejectedPrice;
  String get rejectedSymbol;
  String get rejectedInvalid;

  String what(String side, int quantity, String symbol);
  String filled(String what, String price);
  String waiting(String what, String price);
  String cancelled(String what);
  String rejected(String what);
  String rejectedBecause(String what, String reason);
  String withId(String orderId, String summary);
}

/// Why the server refused to place an order, from its error `code`; any
/// other error reads as [errorText] does.
String rejectionText(OrderStrings orders, ErrorStrings errors, Object error) =>
    switch (error) {
      ServerError(code: 'price_band' || 'price_out_of_band') =>
        orders.rejectedPriceBand,
      ServerError(code: 'insufficient_holdings') => orders.rejectedHoldings,
      ServerError(code: 'insufficient_funds') => orders.rejectedFunds,
      ServerError(code: 'market_closed') => orders.blockClosed,
      ServerError(code: 'invalid_quantity') => orders.rejectedQuantity,
      ServerError(code: 'invalid_price') => orders.rejectedPrice,
      ServerError(code: 'unknown_symbol') => orders.rejectedSymbol,
      ServerError(code: 'invalid_order' || 'invalid_json') =>
        orders.rejectedInvalid,
      _ => errorText(errors, error),
    };
