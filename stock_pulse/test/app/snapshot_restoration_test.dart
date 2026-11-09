import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_book.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

import '../core/storage/storage_fixtures.dart';
import '../helpers/fake_market_repository.dart';

class _SeedableMarket extends FakeMarketRepository
    implements CacheSeedableMarket {
  List<Instrument> seededInstruments = const [];

  @override
  void seedInstruments(List<Instrument> instruments) {
    seededInstruments = instruments;
  }
}

class _SeedablePortfolio extends Fake
    implements PortfolioRepository, CacheSeedablePortfolio {
  PortfolioBook? book;

  @override
  PortfolioBook? get current => book;

  @override
  void seedFromCache(PortfolioBook next) => book = next;
}

void main() {
  test('restores cached quotes, instruments, and portfolio book', () async {
    final market = _SeedableMarket();
    final portfolio = _SeedablePortfolio();
    final snapshot = snapshotWith().copyWith(
      instruments: [
        const Instrument(
          symbol: 'TCS',
          name: 'Tata Consultancy Services',
          exchange: 'NSE',
          sector: 'IT',
          tickSize: 0.05,
          lotSize: 1,
        ),
      ],
    );
    final container = ProviderContainer.test(
      overrides: [
        snapshotProvider.overrideWith((ref) async => snapshot),
        marketRepositoryProvider.overrideWithValue(market),
        portfolioRepositoryProvider.overrideWithValue(portfolio),
      ],
    );
    addTearDown(container.dispose);
    container.read(restoreSnapshotProvider);

    await container.read(snapshotProvider.future);

    expect(market.latestQuotes(snapshot.watchlistIds), snapshot.quotes);
    expect(market.seededInstruments, snapshot.instruments);
    expect(portfolio.current?.positions, snapshot.positions);
    expect(portfolio.current?.holdings, snapshot.holdings);
    expect(
      container.read(restoreSnapshotProvider).cachedBook,
      portfolio.current,
    );
  });

  test('does not overwrite an existing portfolio book', () async {
    final market = _SeedableMarket();
    final portfolio = _SeedablePortfolio()
      ..book = PortfolioBook(positions: const [], holdings: const []);
    final container = ProviderContainer.test(
      overrides: [
        snapshotProvider.overrideWith((ref) async => snapshotWith()),
        marketRepositoryProvider.overrideWithValue(market),
        portfolioRepositoryProvider.overrideWithValue(portfolio),
      ],
    );
    addTearDown(container.dispose);
    container.read(restoreSnapshotProvider);

    await container.read(snapshotProvider.future);

    expect(portfolio.current?.positions, isEmpty);
    expect(container.read(restoreSnapshotProvider).cachedBook, isNull);
  });
}
