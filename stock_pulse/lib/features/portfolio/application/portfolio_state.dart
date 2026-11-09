import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_summary.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';

@immutable
class PortfolioState {
  const PortfolioState({
    required this.orders,
    required this.positions,
    this.quotes = const {},
    this.ltp = const {},
    this.holdings = const [],
    this.loadingHoldings = false,
    this.holdingsFailed = false,
  });

  /// Newest first.
  final List<Order> orders;
  final List<Position> positions;
  final Map<String, Quote> quotes;
  final List<Holding> holdings;
  final bool loadingHoldings;
  final bool holdingsFailed;

  /// Live last price per position symbol, for mark-to-market P&L.
  final Map<String, double> ltp;

  PortfolioSummary get summary => PortfolioSummary.compute(
    positions,
    holdings,
    {
      for (final entry in ltp.entries)
        if (!quotes.containsKey(entry.key))
          entry.key: Quote(
            symbol: entry.key,
            ltp: entry.value,
            change: 0,
            changePercent: 0,
            lastTradeTime: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
      ...quotes,
    },
  );

  double get unrealizedPnl => positions.fold(0, (sum, p) {
    final price = ltp[p.symbol];
    return price == null ? sum : sum + p.unrealizedPnl(price);
  });

  double get realizedPnl => positions.fold(0, (sum, p) => sum + p.realizedPnl);

  PortfolioState copyWith({
    List<Order>? orders,
    List<Holding>? holdings,
    bool? loadingHoldings,
    bool? holdingsFailed,
    List<Position>? positions,
    Map<String, Quote>? quotes,
    Map<String, double>? ltp,
  }) => PortfolioState(
    orders: orders ?? this.orders,
    holdings: holdings ?? this.holdings,
    loadingHoldings: loadingHoldings ?? this.loadingHoldings,
    holdingsFailed: holdingsFailed ?? this.holdingsFailed,
    positions: positions ?? this.positions,
    quotes: quotes ?? this.quotes,
    ltp: ltp ?? this.ltp,
  );

  @override
  bool operator ==(Object other) =>
      other is PortfolioState &&
      listEquals(other.orders, orders) &&
      listEquals(other.positions, positions) &&
      mapEquals(other.quotes, quotes) &&
      listEquals(other.holdings, holdings) &&
      other.loadingHoldings == loadingHoldings &&
      other.holdingsFailed == holdingsFailed &&
      mapEquals(other.ltp, ltp);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(orders),
    Object.hashAll(positions),
    Object.hashAllUnordered(
      quotes.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAll(holdings),
    loadingHoldings,
    holdingsFailed,
    Object.hashAllUnordered(
      ltp.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
