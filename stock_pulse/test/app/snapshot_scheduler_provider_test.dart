import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/storage/data/atomic_json_file.dart';
import 'package:stock_pulse/core/storage/data/file_snapshot_store.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/storage/domain/snapshot_store.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order_repository.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_book.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

import '../helpers/fake_market_repository.dart';
import '../helpers/fake_snapshot_store.dart';

class _Portfolio extends Fake implements PortfolioRepository {
  PortfolioBook? book;

  @override
  PortfolioBook? get current => book;
}

class _Orders extends Fake implements OrderRepository {
  final resync = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get resyncCompleted => resync.stream;

  Future<void> dispose() => resync.close();
}

void main() {
  late FakeSnapshotStore store;
  late _Portfolio portfolio;
  late _Orders orders;

  ProviderContainer make(NetworkStatus status, {SnapshotStore? fileStore}) =>
      ProviderContainer.test(
        overrides: [
          snapshotStoreProvider.overrideWithValue(fileStore ?? store),
          marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
          portfolioRepositoryProvider.overrideWithValue(portfolio),
          orderRepositoryProvider.overrideWithValue(orders),
          networkStatusProvider.overrideWithValue(AsyncData(status)),
        ],
      );

  setUp(() {
    store = FakeSnapshotStore();
    portfolio = _Portfolio();
    orders = _Orders();
  });
  tearDown(() => orders.dispose());

  test('FR-80: a resync while live saves the watchlist and the book', () {
    portfolio.book = PortfolioBook(
      positions: const [],
      holdings: const [Holding(symbol: 'TCS', quantity: 2, averagePrice: 1)],
    );
    final c = make(NetworkStatus.live);
    c.listen(snapshotSchedulerProvider, (_, _) {});

    orders.resync.add(null);

    final saved = store.saved.single as AppSnapshot;
    expect(saved.watchlistIds, isNotEmpty);
    expect(saved.holdings.single.symbol, 'TCS');
  });

  test('FR-87: an offline start with only cached data never saves', () {
    final c = make(NetworkStatus.offline);
    final scheduler = c.listen(snapshotSchedulerProvider, (_, _) {}).read();

    orders.resync.add(null);
    scheduler.onHide();

    expect(store.saved, isEmpty);
  });

  testWidgets('a dirty file store is saved by the 30 s timer', (tester) async {
    portfolio.book = PortfolioBook(positions: const [], holdings: const []);
    final file = FileSnapshotStore(AtomicJsonFile(null, 'snapshot.json'))
      ..markStructuralDirty();
    final c = make(NetworkStatus.live, fileStore: file);
    c.listen(snapshotSchedulerProvider, (_, _) {}).read().onShow();

    await tester.pump(const Duration(seconds: 31));

    expect(file.isDirty, isFalse);
    c.dispose();
  });
}
