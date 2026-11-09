import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/market/application/watchlist_state.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_state.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';

void main() {
  test('portfolio states with equal contents are equal, so select skips', () {
    PortfolioState make({double ltp = 10}) => PortfolioState(
      orders: const [],
      positions: const [
        Position(symbol: 'A', quantity: 1, averagePrice: 9, realizedPnl: 0),
      ],
      holdings: const [Holding(symbol: 'A', quantity: 1, averagePrice: 9)],
      ltp: {'A': ltp},
    );
    expect(make(), make());
    expect(make().hashCode, make().hashCode);
    expect(make(), isNot(make(ltp: 11)));
    expect(make().copyWith(holdingsFailed: true), isNot(make()));
  });

  test('watchlist states with equal contents are equal', () {
    WatchlistState make(Set<String> favourites) => WatchlistState(
      instruments: const [],
      quotes: const {},
      favouriteIds: favourites,
      watchlistOrder: const ['A'],
    );
    expect(make({'A'}), make({'A'}));
    expect(make({'A'}).hashCode, make({'A'}).hashCode);
    expect(make({'A'}), isNot(make({})));
  });
}
