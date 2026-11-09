import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_summary.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';

void main() {
  test('computes totals from holdings, positions, and cached quotes', () {
    const positions = [
      Position(
        symbol: 'TCS',
        quantity: 2,
        averagePrice: 100,
        realizedPnl: 10,
        dayRealizedPnl: 3,
      ),
      Position(
        symbol: 'MISSING',
        quantity: 3,
        averagePrice: 20,
        realizedPnl: 5,
        dayRealizedPnl: 5,
      ),
      Position(symbol: 'ZERO', quantity: 0, averagePrice: 10, realizedPnl: 0),
    ];
    const holdings = [
      Holding(symbol: 'TCS', quantity: 4, averagePrice: 95),
      Holding(symbol: 'MISSING', quantity: 1, averagePrice: 50),
    ];
    final quotes = {
      'TCS': Quote(
        symbol: 'TCS',
        ltp: 110,
        change: 2,
        changePercent: 1.85,
        lastTradeTime: DateTime.utc(2026),
      ),
      'ZERO': Quote(
        symbol: 'ZERO',
        ltp: 20,
        change: 1,
        changePercent: 5,
        lastTradeTime: DateTime.utc(2026),
      ),
    };
    final summary = PortfolioSummary.compute(positions, holdings, quotes);

    expect(summary.invested, 430);
    expect(summary.current, 440);
    expect(summary.realisedToday, 8);
    expect(summary.unrealisedToday, 12);
    expect(summary.dayPnl, 20);
    expect(summary.totalPnl, 90);
    expect(summary, PortfolioSummary.compute(positions, holdings, quotes));
    expect(summary.hashCode, isA<int>());
    expect(PortfolioSummary.empty.totalPnl, 0);
  });
}
