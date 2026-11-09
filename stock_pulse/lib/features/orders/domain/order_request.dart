import 'package:meta/meta.dart';

import 'package:stock_pulse/features/orders/domain/order.dart';

/// Body of `POST /orders`. Options send [lots]; equities send [quantity].
@immutable
class OrderRequest {
  const OrderRequest({
    required this.symbol,
    required this.side,
    required this.type,
    required this.product,
    this.quantity,
    this.lots,
    this.limitPrice,
    this.triggerPrice,
  });

  final String symbol;
  final OrderSide side;
  final OrderType type;
  final ProductType product;
  final int? quantity;
  final int? lots;
  final double? limitPrice;
  final double? triggerPrice;

  Map<String, Object?> toJson() => {
    'symbol': symbol,
    'side': side.name,
    'type': type.name,
    'product': product.name,
    'quantity': ?quantity,
    'lots': ?lots,
    'limitPrice': ?limitPrice,
    'triggerPrice': ?triggerPrice,
  };

  @override
  bool operator ==(Object other) =>
      other is OrderRequest &&
      other.symbol == symbol &&
      other.side == side &&
      other.type == type &&
      other.product == product &&
      other.quantity == quantity &&
      other.lots == lots &&
      other.limitPrice == limitPrice &&
      other.triggerPrice == triggerPrice;

  @override
  int get hashCode => Object.hash(
    symbol,
    side,
    type,
    product,
    quantity,
    lots,
    limitPrice,
    triggerPrice,
  );
}
