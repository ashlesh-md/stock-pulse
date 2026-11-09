import 'package:stock_pulse/core/l10n/strings/order_strings.dart';

final class OrderStringsEn implements OrderStrings {
  const OrderStringsEn();
  @override
  String get blockUnavailable =>
      'Wait for a fresh live price before placing an order.';
  @override
  String get blockClosed => 'The market is closed.';
  @override
  String get blockPreOpen =>
      'Pre-open accepts delivery limit orders for equities only.';
  @override
  String get blockTrigger =>
      'Check the trigger and limit prices against the current price.';
  @override
  String get blockProduct =>
      'This product is not available for this instrument.';
  @override
  String get blockExpired =>
      'This contract has expired. Select another expiry.';
  @override
  String get blockCutoff => 'Intraday orders are closed after 15:20 IST.';
  @override
  String get blockRisk =>
      'Acknowledge the options risk notice before continuing.';
  @override
  String get blockFunds => 'Available funds are below the estimated margin.';
  @override
  String fundsAvailable(String amount) => 'Funds available: $amount';
  @override
  String get marginNotSimulated => 'Margin is not simulated for short options.';
  @override
  String get nudgeLimitFar =>
      'This limit price is more than 3% from the last price.';
  @override
  String nudgeLargeOrder(String percent) =>
      'This order is $percent% of your available funds.';
  @override
  String get nudgeExpiryToday => 'This option expires today.';
  @override
  String get nudgeUnderlyingStale =>
      'The underlying quote is delayed; review the price before confirming.';
  @override
  String get riskTitle => 'Understand options risk';
  @override
  String get riskBody =>
      'Options can lose their entire premium. Selling options can lead to losses beyond the premium received. This is a simulated account; no real trades are placed.';
  @override
  String get riskAgree => 'I understand the risks of trading options.';
  @override
  String get riskContinue => 'Continue to order';

  @override
  String get stopLoss => 'Stop loss';
  @override
  String get triggerPrice => 'Trigger price';
  @override
  String get stopLossHint =>
      'The limit order is sent when the trigger price is reached.';
  @override
  String get product => 'Product';
  @override
  String get delivery => 'Delivery';
  @override
  String get intraday => 'Intraday';
  @override
  String get carryForward => 'Carry forward';
  @override
  String get estimatedValue => 'Estimated value';
  @override
  String get charges => 'Charges';
  @override
  String get chargesHint => 'Simulated account · no brokerage';
  @override
  String get margin => 'Estimated margin';

  @override
  String get pendingPrevious =>
      'The previous order may have been received. Retry the same details to check it safely.';

  @override
  String get statusPending => 'Pending';
  @override
  String get submitting => 'An order is being submitted.';

  @override
  String get placing => 'Placing…';

  @override
  String get checkingStatus => 'Checking status…';

  @override
  String get orderStatusUnknown => 'Order status unknown. See Orders.';

  @override
  String get viewOrders => 'View';

  @override
  String get refreshStatus => 'Refresh status';

  @override
  String get waitingForConnection => 'Waiting for connection';

  @override
  String get buy => 'BUY';
  @override
  String get sell => 'SELL';
  @override
  String get market => 'Market';
  @override
  String get limit => 'Limit';
  @override
  String get quantity => 'Quantity';
  @override
  String get limitPrice => 'Limit price';
  @override
  String get rupeePrefix => '₹ ';
  @override
  String get quantityInvalid => 'Enter a whole number above 0';
  @override
  String get priceInvalid => 'Enter a price';
  @override
  String get limitHintBuy => 'Fills when someone sells at this price or lower.';
  @override
  String get limitHintSell =>
      'Fills when someone buys at this price or higher.';
  @override
  String get marketHintBuy => 'Fills now at the best ask price.';
  @override
  String get marketHintSell => 'Fills now at the best bid price.';
  @override
  String get strategyTitle => 'Strategy builder';
  @override
  String get payoffPreview => 'Preview payoff';
  @override
  String sheetTitle(String symbol, String ltp) => '$symbol · LTP $ltp';
  @override
  String ticketTitle(String symbol) => 'Order · $symbol';
  @override
  String get orderType => 'Order type';
  @override
  String get lotsLabel => 'Lots';
  @override
  String get priceTick => 'Price must be a multiple of the tick size';
  @override
  String get triggerInvalid =>
      'A buy trigger must be at or below the limit; a sell trigger at or above';
  @override
  String get fixFields => 'Fix the highlighted fields to continue';
  @override
  String lotSizeLine(int lotSize) => 'Lot size $lotSize';
  @override
  String unitsTotal(int quantity, String value) => '= $quantity qty · $value';
  @override
  String confirmLabel(String side, String amount, String symbol) =>
      '$side $amount $symbol';
  @override
  String notPlaced(String reason) => 'Order not placed: $reason';

  @override
  String get rejectedPriceBand =>
      'the price is more than 20% away from the previous close';
  @override
  String get rejectedHoldings => 'you do not hold enough shares to sell';
  @override
  String get rejectedFunds => 'you do not have enough available funds';
  @override
  String get rejectedQuantity => 'the quantity must be between 1 and 10,000';
  @override
  String get rejectedPrice => 'a limit order needs a price above 0';
  @override
  String get rejectedSymbol => 'this instrument is not traded';
  @override
  String get rejectedInvalid => 'the order details are incomplete';

  @override
  String what(String side, int quantity, String symbol) =>
      '$side $quantity $symbol';
  @override
  String filled(String what, String price) => '$what filled @ $price';
  @override
  String waiting(String what, String price) =>
      '$what placed · waiting for $price';
  @override
  String cancelled(String what) => '$what cancelled';
  @override
  String rejected(String what) => '$what rejected';
  @override
  String rejectedBecause(String what, String reason) =>
      '$what rejected: $reason';
  @override
  String withId(String orderId, String summary) => '$orderId: $summary';
}
