import 'package:meta/meta.dart';

import 'package:stock_pulse/features/orders/domain/order.dart' show ProductType;

/// Cash settlement of an expired option position.
@immutable
class Settlement {
  const Settlement({
    required this.settlementId,
    required this.symbol,
    required this.product,
    required this.quantity,
    required this.settlePrice,
    required this.pnl,
    required this.settledAt,
  });

  factory Settlement.fromJson(Map<String, Object?> j) => Settlement(
    settlementId: j['settlementId']! as String,
    symbol: j['symbol']! as String,
    product: ProductType.values.byName(j['product']! as String),
    quantity: j['quantity']! as int,
    settlePrice: (j['settlePrice']! as num).toDouble(),
    pnl: (j['pnl']! as num).toDouble(),
    settledAt: DateTime.parse(j['settledAt']! as String),
  );

  /// `"$contractId@$day"`; dedupes replays.
  final String settlementId;
  final String symbol;
  final ProductType product;
  final int quantity;
  final double settlePrice;
  final double pnl;
  final DateTime settledAt;

  @override
  bool operator ==(Object other) =>
      other is Settlement &&
      other.settlementId == settlementId &&
      other.pnl == pnl &&
      other.settledAt == settledAt;

  @override
  int get hashCode => Object.hash(settlementId, pnl, settledAt);
}
