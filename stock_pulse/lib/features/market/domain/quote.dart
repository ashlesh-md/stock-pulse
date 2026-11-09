import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// One price level of the order book.
class DepthLevel {
  const DepthLevel({
    required this.price,
    required this.quantity,
    required this.orders,
  });

  factory DepthLevel.fromJson(Map<String, Object?> json) => DepthLevel(
    price: (json['p']! as num).toDouble(),
    quantity: json['q']! as int,
    orders: json['n']! as int,
  );

  final double price;
  final int quantity;
  final int orders;

  @override
  bool operator ==(Object other) =>
      other is DepthLevel &&
      other.price == price &&
      other.quantity == quantity &&
      other.orders == orders;

  @override
  int get hashCode => Object.hash(price, quantity, orders);
}

/// Live market data for one stock.
///
/// The feed sends only the fields of the subscribed mode (ltp mode has no
/// open/high/low), so [mergeJson] keeps the old value of every field the
/// message left out. `==` compares every field: Riverpod's `select` uses it
/// to rebuild a row only when ITS quote really changed.
@immutable
class Quote {
  const Quote({
    required this.symbol,
    required this.ltp,
    required this.change,
    required this.changePercent,
    required this.lastTradeTime,
    this.open,
    this.high,
    this.low,
    this.prevClose,
    this.volume,
    this.lastQuantity,
    this.bid,
    this.ask,
    this.bids = const [],
    this.asks = const [],
    DateTime? asOf,
    this.seq = 0,
    this.fromCache = false,
    this.iep = false,
  }) : asOf = asOf ?? lastTradeTime;

  factory Quote.fromJson(Map<String, Object?> json) => Quote(
    symbol: '',
    ltp: 0,
    change: 0,
    changePercent: 0,
    lastTradeTime: _epoch,
  ).mergeJson(json);

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  final String symbol;

  /// Last traded price.
  final double ltp;

  /// ltp − previous close, and the same as a percentage.
  final double change;
  final double changePercent;
  final DateTime lastTradeTime;

  final double? open;
  final double? high;
  final double? low;
  final double? prevClose;

  /// Shares traded today (cumulative).
  final int? volume;
  final int? lastQuantity;

  /// Best price a buyer is offering / a seller is asking.
  final double? bid;
  final double? ask;

  /// Order book, best first. Empty unless subscribed in full mode.
  final List<DepthLevel> bids;
  final List<DepthLevel> asks;

  /// Server wall time this value was last confirmed. Not part of
  /// `==`: a keep-alive re-emits an equal quote with a newer [asOf].
  final DateTime asOf;

  /// Frame seq that last touched it. Not part of `==`.
  final int seq;

  /// Seeded from the snapshot cache, not yet confirmed live.
  final bool fromCache;

  /// Pre-open indicative equilibrium price.
  final bool iep;

  /// Protocol names for [symbol] and [changePercent].
  String get id => symbol;
  double get changePct => changePercent;

  bool get isUp => change >= 0;
  double? get spread => bid == null || ask == null ? null : ask! - bid!;

  Quote mergeJson(Map<String, Object?> json) {
    double? d(String key) => (json[key] as num?)?.toDouble();
    final depth = json['depth'] as Map<String, Object?>?;
    List<DepthLevel>? levels(String side) => depth == null
        ? null
        : [
            for (final l in depth[side]! as List)
              DepthLevel.fromJson(l as Map<String, Object?>),
          ];
    final t = json['t'] as int?;
    final asOfMs = json['asOf'] as int?;
    final tradeTime = t == null
        ? lastTradeTime
        : DateTime.fromMillisecondsSinceEpoch(t, isUtc: true);
    return Quote(
      symbol: json['s'] as String? ?? symbol,
      ltp: d('ltp') ?? ltp,
      change: d('ch') ?? change,
      changePercent: d('chp') ?? changePercent,
      lastTradeTime: tradeTime,
      open: d('o') ?? open,
      high: d('h') ?? high,
      low: d('l') ?? low,
      prevClose: d('pc') ?? prevClose,
      volume: json['v'] as int? ?? volume,
      lastQuantity: json['lq'] as int? ?? lastQuantity,
      bid: d('bid') ?? bid,
      ask: d('ask') ?? ask,
      bids: levels('bids') ?? bids,
      asks: levels('asks') ?? asks,
      // A frame without asOf: the trade time is the best confirmation.
      asOf: asOfMs != null
          ? DateTime.fromMillisecondsSinceEpoch(asOfMs, isUtc: true)
          : (t == null ? asOf : tradeTime),
      seq: seq,
      fromCache: fromCache,
      iep: json['iep'] as bool? ?? iep,
    );
  }

  /// Only freshness metadata changes; price fields stay.
  Quote copyWith({DateTime? asOf, int? seq, bool? fromCache}) => Quote(
    symbol: symbol,
    ltp: ltp,
    change: change,
    changePercent: changePercent,
    lastTradeTime: lastTradeTime,
    open: open,
    high: high,
    low: low,
    prevClose: prevClose,
    volume: volume,
    lastQuantity: lastQuantity,
    bid: bid,
    ask: ask,
    bids: bids,
    asks: asks,
    asOf: asOf ?? this.asOf,
    seq: seq ?? this.seq,
    fromCache: fromCache ?? this.fromCache,
    iep: iep,
  );

  /// Wire keys, so [Quote.fromJson] reads it back (snapshot cache). Depth is
  /// not cached.
  Map<String, Object?> toJson() => {
    's': symbol,
    'ltp': ltp,
    'ch': change,
    'chp': changePercent,
    't': lastTradeTime.millisecondsSinceEpoch,
    'o': ?open,
    'h': ?high,
    'l': ?low,
    'pc': ?prevClose,
    'v': ?volume,
    'lq': ?lastQuantity,
    'bid': ?bid,
    'ask': ?ask,
    'asOf': asOf.millisecondsSinceEpoch,
    if (iep) 'iep': true,
  };

  @override
  bool operator ==(Object other) =>
      other is Quote &&
      other.symbol == symbol &&
      other.ltp == ltp &&
      other.change == change &&
      other.changePercent == changePercent &&
      other.lastTradeTime == lastTradeTime &&
      other.open == open &&
      other.high == high &&
      other.low == low &&
      other.prevClose == prevClose &&
      other.volume == volume &&
      other.lastQuantity == lastQuantity &&
      other.bid == bid &&
      other.ask == ask &&
      const ListEquality<Object?>().equals(other.bids, bids) &&
      const ListEquality<Object?>().equals(other.asks, asks) &&
      other.fromCache == fromCache &&
      other.iep == iep;

  @override
  int get hashCode => Object.hash(
    symbol,
    ltp,
    change,
    changePercent,
    lastTradeTime,
    open,
    high,
    low,
    prevClose,
    volume,
    lastQuantity,
    bid,
    ask,
    Object.hashAll(bids),
    Object.hashAll(asks),
    fromCache,
    iep,
  );
}
