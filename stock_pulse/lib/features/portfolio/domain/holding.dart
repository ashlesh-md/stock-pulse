import 'package:meta/meta.dart';

/// Delivery shares carried from earlier days (CNC).
@immutable
class Holding {
  const Holding({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
    this.version = 0,
  });

  factory Holding.fromJson(Map<String, Object?> j) => Holding(
    symbol: j['symbol']! as String,
    quantity: j['quantity']! as int,
    averagePrice: (j['averagePrice']! as num).toDouble(),
    version: j['version'] as int? ?? 0,
  );

  final String symbol;
  final int quantity;
  final double averagePrice;
  final int version;

  Map<String, Object?> toJson() => {
    'symbol': symbol,
    'quantity': quantity,
    'averagePrice': averagePrice,
    'version': version,
  };

  @override
  bool operator ==(Object other) =>
      other is Holding &&
      other.symbol == symbol &&
      other.quantity == quantity &&
      other.averagePrice == averagePrice &&
      other.version == version;

  @override
  int get hashCode => Object.hash(symbol, quantity, averagePrice, version);
}
