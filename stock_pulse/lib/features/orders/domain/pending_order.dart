import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';

@immutable
class PendingOrder {
  const PendingOrder({
    required this.clientKey,
    required this.request,
    required this.createdAt,
  });

  factory PendingOrder.fromJson(Map<String, Object?> json) {
    final request = json['request']! as Map<String, Object?>;
    return PendingOrder(
      clientKey: json['clientKey']! as String,
      request: OrderRequest(
        symbol: request['symbol']! as String,
        side: OrderSide.values.byName(request['side']! as String),
        type: OrderType.values.byName(request['type']! as String),
        product: ProductType.values.byName(request['product']! as String),
        quantity: request['quantity'] as int?,
        lots: request['lots'] as int?,
        limitPrice: (request['limitPrice'] as num?)?.toDouble(),
        triggerPrice: (request['triggerPrice'] as num?)?.toDouble(),
      ),
      createdAt: DateTime.parse(json['createdAt']! as String),
    );
  }

  final String clientKey;
  final OrderRequest request;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'clientKey': clientKey,
    'createdAt': createdAt.toIso8601String(),
    'request': request.toJson(),
  };

  Order toOrder() => Order(
    id: 'pending:$clientKey',
    clientKey: clientKey,
    symbol: request.symbol,
    side: request.side,
    type: request.type,
    product: request.product,
    quantity: request.quantity ?? 0,
    lots: request.lots,
    limitPrice: request.limitPrice,
    triggerPrice: request.triggerPrice,
    status: OrderStatus.pending,
    createdAt: createdAt,
    updatedAt: createdAt,
  );

  @override
  bool operator ==(Object other) =>
      other is PendingOrder &&
      other.clientKey == clientKey &&
      other.request == request &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(clientKey, request, createdAt);
}
