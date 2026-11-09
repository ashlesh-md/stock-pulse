import 'package:meta/meta.dart';

enum OrderSide { buy, sell }

/// cnc = delivery (equity), mis = intraday (squared off 15:20), nrml = F&O
/// carry-forward.
enum ProductType { cnc, mis, nrml }

enum OrderType { market, limit, sl }

/// `queued` = pre-open limit order waiting for 09:15; `triggerPending` = SL
/// order waiting for its trigger.
enum OrderStatus {
  pending,
  queued,
  open,
  triggerPending,
  complete,
  cancelled,
  rejected,
}

/// An order as the server knows it. [version] is the server's global
/// version: the higher one wins when a frame and a REST answer race.
@immutable
class Order {
  const Order({
    required this.id,
    required this.symbol,
    required this.side,
    required this.type,
    required this.quantity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.version = 0,
    this.product = ProductType.cnc,
    this.clientKey,
    this.lots,
    this.limitPrice,
    this.triggerPrice,
    this.averagePrice,
    this.reason,
    this.message,
  });

  factory Order.fromJson(Map<String, Object?> j) => Order(
    id: j['id']! as String,
    clientKey: j['clientKey'] as String?,
    version: j['version'] as int? ?? 0,
    symbol: j['symbol']! as String,
    product: ProductType.values.byName(j['product'] as String? ?? 'cnc'),
    side: OrderSide.values.byName(j['side']! as String),
    type: OrderType.values.byName(j['type']! as String),
    quantity: j['quantity']! as int,
    lots: j['lots'] as int?,
    limitPrice: (j['limitPrice'] as num?)?.toDouble(),
    triggerPrice: (j['triggerPrice'] as num?)?.toDouble(),
    averagePrice: (j['averagePrice'] as num?)?.toDouble(),
    status: OrderStatus.values.byName(j['status']! as String),
    reason: j['reason'] as String?,
    message: j['message'] as String?,
    createdAt: DateTime.parse(j['createdAt']! as String),
    updatedAt: DateTime.parse(j['updatedAt']! as String),
  );

  final String id;

  /// The Idempotency-Key it was placed with; null for server orders
  /// (auto square-off).
  final String? clientKey;
  final int version;
  final String symbol;
  final ProductType product;
  final OrderSide side;
  final OrderType type;
  final int quantity;
  final int? lots;
  final double? limitPrice;
  final double? triggerPrice;
  final double? averagePrice;
  final OrderStatus status;

  /// Machine reason, e.g. `auto_square_off`, `expired`, a rejection code.
  final String? reason;
  final String? message;

  /// Market time.
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      other is Order &&
      other.id == id &&
      other.version == version &&
      other.status == status &&
      other.averagePrice == averagePrice &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, version, status, averagePrice, updatedAt);
}
