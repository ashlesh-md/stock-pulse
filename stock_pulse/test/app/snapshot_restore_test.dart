import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:option_math/option_math.dart' show OptionRight;
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_book.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

import '../core/storage/storage_fixtures.dart';
import '../helpers/fake_market_repository.dart';

const option = Instrument(
  symbol: 'NIFTY25NOV24000CE',
  name: 'NIFTY 24000 CE',
  exchange: 'NFO',
  sector: 'Index',
  tickSize: 0.05,
  lotSize: 75,
  kind: InstrumentKind.option,
  underlying: 'NIFTY',
  expiry: '2026-11-25',
  strike: 24000,
  right: OptionRight.ce,
);

class _Market extends FakeMarketRepository implements CacheSeedableMarket {
  List<Instrument>? instruments;

  @override
  void seedInstruments(List<Instrument> i) => instruments = i;
}

class _Portfolio extends Fake
    implements PortfolioRepository, CacheSeedablePortfolio {
  @override
  PortfolioBook? current;

  @override
  void seedFromCache(PortfolioBook book) => current = book;
}

void main() {
  test('instruments round-trip with their option fields', () {
    final snap = snapshotWith().copyWith(instruments: [option]);
    final back = AppSnapshot.fromJson(snap.toJson()).instruments.single;
    expect(
      (back.kind, back.underlying, back.expiry, back.strike, back.right),
      (InstrumentKind.option, 'NIFTY', '2026-11-25', 24000, OptionRight.ce),
    );
    expect(back.lotSize, 75);
  });

  test('restore seeds quotes, instruments and an empty portfolio', () async {
    final market = _Market();
    final portfolio = _Portfolio();
    final snap = snapshotWith().copyWith(instruments: [option]);
    final c = ProviderContainer.test(
      overrides: [
        snapshotProvider.overrideWith((ref) async => snap),
        marketRepositoryProvider.overrideWithValue(market),
        portfolioRepositoryProvider.overrideWithValue(portfolio),
      ],
    );
    final restoration = c.read(restoreSnapshotProvider);
    await c.read(snapshotProvider.future);
    await pumpEventQueue();
    expect(market.instruments, [option]);
    expect(portfolio.current?.positions, snap.positions);
    expect(restoration.cachedBook, portfolio.current);
  });

  test('a missing snapshot seeds nothing', () async {
    final market = _Market();
    final c = ProviderContainer.test(
      overrides: [
        snapshotProvider.overrideWith((ref) async => null),
        marketRepositoryProvider.overrideWithValue(market),
        portfolioRepositoryProvider.overrideWithValue(_Portfolio()),
      ],
    );
    c.read(restoreSnapshotProvider);
    await c.read(snapshotProvider.future);
    expect(market.instruments, isNull);
  });
}
