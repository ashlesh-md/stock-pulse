import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_state.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_summary.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';

void main() {
  test('PortfolioState derives P&L and preserves values with copyWith', () {
    const position = Position(
      symbol: 'TCS',
      quantity: 2,
      averagePrice: 3000,
      realizedPnl: 25,
    );
    const holding = Holding(symbol: 'INFY', quantity: 4, averagePrice: 1400);
    const original = PortfolioState(
      orders: [],
      positions: [position],
      holdings: [holding],
      ltp: {'TCS': 3100},
    );
    expect(original.unrealizedPnl, 200);
    expect(original.realizedPnl, 25);

    final loading = original.copyWith(loadingHoldings: true);
    expect(loading.loadingHoldings, isTrue);
    expect(loading.holdings, [holding]);
    expect(loading.ltp, {'TCS': 3100});
    expect(loading, isNot(original));
    expect(loading.copyWith(loadingHoldings: false), original);
  });

  test('warm state derives its summary from cached portfolio facts', () {
    final quote = Quote(
      symbol: 'INFY',
      ltp: 1600,
      change: 10,
      changePercent: .63,
      lastTradeTime: DateTime.utc(2026),
      fromCache: true,
    );
    const holding = Holding(symbol: 'INFY', quantity: 5, averagePrice: 1500);
    const state = PortfolioState(
      orders: [],
      positions: [],
      holdings: [holding],
    );
    final seeded = state.copyWith(quotes: {'INFY': quote});

    expect(
      seeded.summary,
      PortfolioSummary.compute([], const [holding], {'INFY': quote}),
    );
    expect(seeded.summary.invested, 7500);
    expect(seeded.summary.current, 8000);
    expect(seeded.summary.dayPnl, 50);
    expect(seeded.summary.totalPnl, 500);
  });
}
