import 'package:meta/meta.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';

/// Derived portfolio totals. Snapshots store positions, holdings and quotes;
/// these numbers are recomputed from those facts on every state update.
@immutable
class PortfolioSummary {
  const PortfolioSummary({
    required this.invested,
    required this.current,
    required this.dayPnl,
    required this.totalPnl,
    required this.realisedToday,
    required this.unrealisedToday,
  });

  static const empty = PortfolioSummary(
    invested: 0,
    current: 0,
    dayPnl: 0,
    totalPnl: 0,
    realisedToday: 0,
    unrealisedToday: 0,
  );

  final double invested;
  final double current;
  final double dayPnl;
  final double totalPnl;
  final double realisedToday;
  final double unrealisedToday;

  static PortfolioSummary compute(
    List<Position> positions,
    List<Holding> holdings,
    Map<String, Quote> quotes,
  ) {
    var invested = 0.0;
    var current = 0.0;
    var holdingsDay = 0.0;
    var holdingsTotal = 0.0;
    var realisedToday = 0.0;
    var positionsDay = 0.0;
    var positionsTotal = 0.0;

    for (final holding in holdings) {
      invested += holding.averagePrice * holding.quantity;
      final quote = quotes[holding.symbol];
      if (quote == null) continue;
      current += quote.ltp * holding.quantity;
      holdingsDay += quote.change * holding.quantity;
      holdingsTotal += (quote.ltp - holding.averagePrice) * holding.quantity;
    }
    for (final position in positions) {
      realisedToday += position.dayRealizedPnl;
      final quote = quotes[position.symbol];
      if (quote == null || position.quantity == 0) continue;
      positionsDay += quote.change * position.quantity;
      positionsTotal +=
          position.realizedPnl + position.unrealizedPnl(quote.ltp);
    }
    final unrealisedToday = holdingsDay + positionsDay;
    return PortfolioSummary(
      invested: invested,
      current: current,
      dayPnl: realisedToday + unrealisedToday,
      totalPnl: holdingsTotal + positionsTotal,
      realisedToday: realisedToday,
      unrealisedToday: unrealisedToday,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PortfolioSummary &&
      other.invested == invested &&
      other.current == current &&
      other.dayPnl == dayPnl &&
      other.totalPnl == totalPnl &&
      other.realisedToday == realisedToday &&
      other.unrealisedToday == unrealisedToday;

  @override
  int get hashCode => Object.hash(
    invested,
    current,
    dayPnl,
    totalPnl,
    realisedToday,
    unrealisedToday,
  );
}
