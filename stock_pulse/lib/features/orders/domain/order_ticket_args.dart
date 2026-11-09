import 'package:meta/meta.dart';

import 'package:stock_pulse/features/orders/domain/order.dart'
    show OrderSide, ProductType;

/// Where an order ticket or alert sheet was opened from.
enum OrderSource {
  manual,
  watchlist,
  chart,
  chain,
  ai,
  alert,
  deeplink,
  position,
}

/// Prefill for `openOrderTicket`. Null fields fall back to ticket defaults
/// (1 lot, product by instrument kind, market order).
@immutable
class OrderTicketArgs {
  const OrderTicketArgs({
    required this.instrumentId,
    required this.side,
    this.lots,
    this.product,
    this.limitPrice,
    this.source = OrderSource.manual,
  });

  final String instrumentId;
  final OrderSide side;
  final int? lots;
  final ProductType? product;
  final double? limitPrice;
  final OrderSource source;

  OrderTicketArgs copyWith({
    String? instrumentId,
    OrderSide? side,
    int? lots,
    ProductType? product,
    double? limitPrice,
    OrderSource? source,
  }) => OrderTicketArgs(
    instrumentId: instrumentId ?? this.instrumentId,
    side: side ?? this.side,
    lots: lots ?? this.lots,
    product: product ?? this.product,
    limitPrice: limitPrice ?? this.limitPrice,
    source: source ?? this.source,
  );

  @override
  bool operator ==(Object other) =>
      other is OrderTicketArgs &&
      other.instrumentId == instrumentId &&
      other.side == side &&
      other.lots == lots &&
      other.product == product &&
      other.limitPrice == limitPrice &&
      other.source == source;

  @override
  int get hashCode =>
      Object.hash(instrumentId, side, lots, product, limitPrice, source);

  @override
  String toString() =>
      'OrderTicketArgs($instrumentId, $side, lots: $lots, product: $product, '
      'limit: $limitPrice, source: $source)';
}
