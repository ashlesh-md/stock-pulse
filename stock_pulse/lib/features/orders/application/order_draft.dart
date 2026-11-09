import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/orders/domain/order.dart'
    show OrderSide, OrderType, ProductType;
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';

/// A field the user must fix before the order can be sent.
enum DraftIssue { quantity, price, trigger }

/// What a sheet opens with: the prefill plus the contract facts the
/// opener already loaded.
typedef OrderDraftSeed = ({
  OrderTicketArgs args,
  int lotSize,
  double tickSize,
  double ltp,
});

/// The order being filled in. [count] is lots when [lotSize] > 1, else
/// shares; null while the field does not hold a whole number.
@immutable
class OrderDraft {
  const OrderDraft({
    required this.side,
    required this.type,
    required this.product,
    required this.count,
    required this.lotSize,
    required this.tickSize,
    required this.ltp,
    this.limitPrice,
    this.triggerPrice,
    this.submitting = false,
    this.error,
  });

  factory OrderDraft.fromSeed(OrderDraftSeed seed) => OrderDraft(
    side: seed.args.side,
    type: seed.args.limitPrice == null ? OrderType.market : OrderType.limit,
    product:
        seed.args.product ??
        (seed.lotSize > 1 ? ProductType.nrml : ProductType.cnc),
    count: seed.args.lots ?? 1,
    lotSize: seed.lotSize,
    tickSize: seed.tickSize,
    ltp: seed.ltp,
    limitPrice: seed.args.limitPrice ?? seed.ltp,
    triggerPrice: seed.ltp,
  );

  static const maxCount = 10000;

  final OrderSide side;
  final OrderType type;
  final ProductType product;
  final int? count;
  final int lotSize;
  final double tickSize;

  /// Price when the sheet opened; market orders are estimated at it.
  final double ltp;
  final double? limitPrice;
  final double? triggerPrice;
  final bool submitting;

  /// Why the last send failed, already in the user's language.
  final String? error;

  bool get inLots => lotSize > 1;
  int get quantity => (count ?? 0) * lotSize;
  int? get lots => inLots ? count : null;
  double? get sentLimit => type == OrderType.market ? null : limitPrice;
  double? get sentTrigger => type == OrderType.sl ? triggerPrice : null;
  double get estimatedPrice => sentLimit ?? ltp;
  double get orderValue => quantity * estimatedPrice;

  Set<DraftIssue> get issues => {
    if (count == null || count! < 1 || count! > maxCount) DraftIssue.quantity,
    if (type != OrderType.market && !_onTick(limitPrice)) DraftIssue.price,
    if (type == OrderType.sl && !_validTrigger) DraftIssue.trigger,
  };

  bool get _validTrigger {
    final trigger = triggerPrice;
    final limit = limitPrice;
    if (!_onTick(trigger) || limit == null) return false;
    return side == OrderSide.buy ? trigger! <= limit : trigger! >= limit;
  }

  bool _onTick(double? price) {
    if (price == null || !price.isFinite || price <= 0) return false;
    final ticks = price / tickSize;
    return (ticks - ticks.round()).abs() < 1e-6;
  }

  OrderDraft copyWith({
    OrderSide? side,
    OrderType? type,
    ProductType? product,
    int? Function()? count,
    double? Function()? limitPrice,
    double? Function()? triggerPrice,
    bool? submitting,
    String? Function()? error,
  }) => OrderDraft(
    side: side ?? this.side,
    type: type ?? this.type,
    product: product ?? this.product,
    count: count == null ? this.count : count(),
    lotSize: lotSize,
    tickSize: tickSize,
    ltp: ltp,
    limitPrice: limitPrice == null ? this.limitPrice : limitPrice(),
    triggerPrice: triggerPrice == null ? this.triggerPrice : triggerPrice(),
    submitting: submitting ?? this.submitting,
    error: error == null ? this.error : error(),
  );

  @override
  bool operator ==(Object other) =>
      other is OrderDraft &&
      other.side == side &&
      other.type == type &&
      other.product == product &&
      other.count == count &&
      other.lotSize == lotSize &&
      other.tickSize == tickSize &&
      other.ltp == ltp &&
      other.limitPrice == limitPrice &&
      other.triggerPrice == triggerPrice &&
      other.submitting == submitting &&
      other.error == error;

  @override
  int get hashCode => Object.hash(
    side,
    type,
    product,
    count,
    lotSize,
    tickSize,
    ltp,
    limitPrice,
    triggerPrice,
    submitting,
    error,
  );
}
