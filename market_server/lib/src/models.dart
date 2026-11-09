// Plain data classes the server sends as JSON. Prices are doubles rounded to
// the tick size (0.05). Real Indian brokers send prices as integer paise to
// avoid floating-point drift; see the README for why.

import 'package:option_math/option_math.dart' show OptionRight;

enum InstrumentKind {
  marketIndex('index'),
  equity('equity'),
  option('option');

  const InstrumentKind(this.wire);

  final String wire;
}

class Instrument {
  const Instrument({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.sector,
    required this.basePrice,
    this.tickSize = 0.05,
    this.lotSize = 1,
    this.kind = InstrumentKind.equity,
    this.bandPct = 0.20,
    this.weight = 0,
    this.strikeStep,
    this.underlying,
    this.expiry,
    this.strike,
    this.right,
  });

  final String symbol;
  final String name;
  final String exchange;
  final String sector;

  final double basePrice;
  final double tickSize;
  final int lotSize;
  final InstrumentKind kind;

  final double? bandPct;

  final double weight;

  final int? strikeStep;

  final String? underlying;
  final String? expiry;
  final int? strike;
  final OptionRight? right;

  bool get tradable => kind != InstrumentKind.marketIndex;

  ({double low, double high})? bandFor(double prevClose) {
    double down(double v) => _tick((v / tickSize + 1e-9).floorToDouble());
    double up(double v) => _tick((v / tickSize - 1e-9).ceilToDouble());
    if (kind == InstrumentKind.option) {
      return (low: tickSize, high: down(prevClose * 3));
    }
    final pct = bandPct;
    if (pct == null) return null;
    return (low: up(prevClose * (1 - pct)), high: down(prevClose * (1 + pct)));
  }

  double _tick(double ticks) => (ticks * tickSize * 100).roundToDouble() / 100;

  Map<String, Object?> toJson({double? prevClose}) {
    final band = prevClose == null ? null : bandFor(prevClose);
    return {
      'id': symbol,
      'symbol': symbol,
      'name': name,
      'exchange': exchange,
      'sector': sector,
      'kind': kind.wire,
      'tickSize': tickSize,
      'lotSize': lotSize,
      if (band != null) 'bandLow': band.low,
      if (band != null) 'bandHigh': band.high,
      if (strikeStep != null) 'strikeStep': strikeStep,
      if (underlying != null) 'underlying': underlying,
      if (expiry != null) 'expiry': expiry,
      if (strike != null) 'strike': strike,
      if (right != null) 'right': right!.name.toUpperCase(),
    };
  }
}

class Candle {
  Candle({
    required this.start,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final DateTime start;
  double open;
  double high;
  double low;
  double close;
  int volume;

  void add(double price, int qty) {
    if (price > high) high = price;
    if (price < low) low = price;
    close = price;
    volume += qty;
  }

  Map<String, Object?> toJson() => {
    't': start.millisecondsSinceEpoch,
    'o': open,
    'h': high,
    'l': low,
    'c': close,
    'v': volume,
  };
}

class DepthLevel {
  const DepthLevel(this.price, this.quantity, this.orders);

  final double price;
  final int quantity;
  final int orders;

  Map<String, Object?> toJson() => {'p': price, 'q': quantity, 'n': orders};
}

enum OrderSide { buy, sell }

enum OrderType { market, limit, sl }

enum ProductType { cnc, mis, nrml }

enum OrderStatus { open, complete, cancelled, rejected, queued, triggerPending }

class Order {
  Order({
    required this.id,
    required this.symbol,
    required this.side,
    required this.type,
    required this.quantity,
    required this.limitPrice,
    required this.createdAt,
    this.product = ProductType.mis,
    this.lots,
    this.triggerPrice,
    this.clientKey,
    this.version = 0,
  }) : updatedAt = createdAt;

  final String id;
  final ProductType product;
  final int? lots;
  final double? triggerPrice;
  final String? clientKey;
  int version;
  final String symbol;
  final OrderSide side;
  final OrderType type;
  final int quantity;
  final double? limitPrice;
  final DateTime createdAt;

  OrderStatus status = OrderStatus.open;
  double? averagePrice;
  String? message;
  String? reason;
  DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'product': product.name,
    'lots': lots,
    'triggerPrice': triggerPrice,
    'clientKey': clientKey,
    'version': version,
    'symbol': symbol,
    'side': side.name,
    'type': type.name,
    'quantity': quantity,
    'limitPrice': limitPrice,
    'status': status.name,
    'averagePrice': averagePrice,
    'message': message,
    'reason': reason,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class Position {
  Position(this.symbol, {this.product = ProductType.mis});

  final String symbol;
  final ProductType product;
  int version = 0;

  int quantity = 0;
  double averagePrice = 0;
  double realizedPnl = 0;

  void apply(OrderSide side, int qty, double price) {
    final signed = side == OrderSide.buy ? qty : -qty;
    final sameDirection = quantity == 0 || (quantity > 0) == (signed > 0);
    if (sameDirection) {
      final newQty = quantity + signed;
      averagePrice =
          (averagePrice * quantity.abs() + price * qty) / newQty.abs();
      quantity = newQty;
      return;
    }
    final closing = qty < quantity.abs() ? qty : quantity.abs();
    final perShare = quantity > 0 ? price - averagePrice : averagePrice - price;
    realizedPnl += perShare * closing;
    quantity += signed;
    if (quantity == 0) {
      averagePrice = 0;
    } else if (closing < qty) {
      // Flipped from long to short (or back): the leftover opens at `price`.
      averagePrice = price;
    }
  }

  Map<String, Object?> toJson() => {
    'symbol': symbol,
    'product': product.name,
    'version': version,
    'quantity': quantity,
    'averagePrice': double.parse(averagePrice.toStringAsFixed(2)),
    'realizedPnl': double.parse(realizedPnl.toStringAsFixed(2)),
  };
}
