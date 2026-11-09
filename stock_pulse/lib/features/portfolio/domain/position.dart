import 'package:meta/meta.dart';

import 'package:stock_pulse/features/orders/domain/order.dart' show ProductType;

/// Net position per (symbol, product); not netted across products.
/// The wire JSON is also the snapshot JSON.
@immutable
class Position {
  const Position({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
    required this.realizedPnl,
    this.product = ProductType.cnc,
    this.lots,
    this.dayRealizedPnl = 0,
    this.version = 0,
  });

  factory Position.fromJson(Map<String, Object?> j) => Position(
    symbol: j['symbol']! as String,
    product: ProductType.values.byName(j['product'] as String? ?? 'cnc'),
    quantity: j['quantity']! as int,
    lots: j['lots'] as int?,
    averagePrice: (j['averagePrice']! as num).toDouble(),
    realizedPnl: (j['realizedPnl']! as num).toDouble(),
    dayRealizedPnl: (j['dayRealizedPnl'] as num? ?? 0).toDouble(),
    version: j['version'] as int? ?? 0,
  );

  final String symbol;
  final ProductType product;

  /// Positive = long, negative = short.
  final int quantity;
  final int? lots;
  final double averagePrice;
  final double realizedPnl;
  final double dayRealizedPnl;
  final int version;

  /// Merge key in repositories.
  String get key => '$symbol|${product.name}';

  /// Profit or loss if closed at [ltp] now ("mark to market").
  double unrealizedPnl(double ltp) => (ltp - averagePrice) * quantity;

  Map<String, Object?> toJson() => {
    'symbol': symbol,
    'product': product.name,
    'quantity': quantity,
    'lots': lots,
    'averagePrice': averagePrice,
    'realizedPnl': realizedPnl,
    'dayRealizedPnl': dayRealizedPnl,
    'version': version,
  };

  @override
  bool operator ==(Object other) =>
      other is Position &&
      other.symbol == symbol &&
      other.product == product &&
      other.quantity == quantity &&
      other.lots == lots &&
      other.averagePrice == averagePrice &&
      other.realizedPnl == realizedPnl &&
      other.dayRealizedPnl == dayRealizedPnl &&
      other.version == version;

  @override
  int get hashCode => Object.hash(
    symbol,
    product,
    quantity,
    lots,
    averagePrice,
    realizedPnl,
    dayRealizedPnl,
    version,
  );
}
