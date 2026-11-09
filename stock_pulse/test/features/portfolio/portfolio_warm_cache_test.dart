import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_funds_provider.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_book.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_summary.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';

import '../../helpers/fake_pending_order_store.dart';

class _Portfolio extends Mock implements PortfolioRepository {}

class _Market extends Mock implements MarketRepository {}

void main() {
  setUpAll(() => registerFallbackValue(FeedMode.ltp));

  test('warm cached book paints its computed summary while offline', () async {
    const position = Position(
      symbol: 'TCS',
      quantity: 7,
      averagePrice: 3000,
      realizedPnl: 0,
    );
    const holding = Holding(symbol: 'INFY', quantity: 5, averagePrice: 1500);
    final positionQuote = Quote(
      symbol: 'TCS',
      ltp: 3100,
      change: 12,
      changePercent: .39,
      lastTradeTime: DateTime.utc(2026, 11, 4, 5),
      fromCache: true,
    );
    final holdingQuote = Quote(
      symbol: 'INFY',
      ltp: 1600,
      change: 10,
      changePercent: .63,
      lastTradeTime: DateTime.utc(2026, 11, 4, 5),
      fromCache: true,
    );
    final portfolio = _Portfolio();
    final market = _Market();
    final quotes = [positionQuote, holdingQuote];
    when(() => portfolio.orderUpdates).thenAnswer((_) => const Stream.empty());
    when(portfolio.getOrders).thenAnswer((_) async => const Success([]));
    when(portfolio.getPositions)
        .thenAnswer((_) async => const Failure(NetworkError()));
    when(portfolio.getHoldings)
        .thenAnswer((_) async => const Failure(NetworkError()));
    when(portfolio.watchHoldings).thenAnswer((_) => const Stream.empty());
    when(() => portfolio.current).thenReturn(
      PortfolioBook(positions: const [position], holdings: const [holding]),
    );
    when(() => market.latestQuotes(any())).thenReturn(quotes);
    when(() => market.watchQuotes(any(), any()))
        .thenAnswer((_) => const Stream.empty());

    final container = ProviderContainer.test(
      overrides: [
        fakePendingOrderStoreOverride(),
        portfolioRepositoryProvider.overrideWithValue(portfolio),
        portfolioFundsProvider.overrideWith((ref) => const Stream.empty()),
        marketRepositoryProvider.overrideWithValue(market),
        socketStatusProvider.overrideWith((ref) => const Stream.empty()),
        networkStatusProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    container.listen(portfolioControllerProvider, (_, _) {});
    final seeded = await container.read(portfolioControllerProvider.future);
    await container.read(portfolioControllerProvider.notifier).loadHoldings();
    final painted = container.read(portfolioControllerProvider).requireValue;
    final computed = PortfolioSummary.compute(
      const [position],
      const [holding],
      {'TCS': positionQuote, 'INFY': holdingQuote},
    );

    expect(painted.holdings, [holding]);
    expect(painted.holdingsFailed, isFalse);
    expect(painted.summary, computed);
    expect(painted.summary.invested, 7500);
    expect(painted.summary.current, 8000);
    expect(seeded.summary, computed);
    final symbols =
        verify(() => market.watchQuotes(captureAny(), FeedMode.ltp))
                .captured
                .single
            as List<String>;
    expect(symbols.toSet(), {'TCS', 'INFY'});
  });
}
