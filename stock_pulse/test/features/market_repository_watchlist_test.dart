import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/features/market/data/live_market_repository.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

import '../helpers/fake_market_socket.dart';
import '../helpers/fake_snapshot_store.dart';

void main() {
  late FakeMarketSocket socket;
  late FakeSnapshotStore store;
  late MarketRepository repo;

  setUp(() {
    socket = FakeMarketSocket();
    store = FakeSnapshotStore();
    repo = LiveMarketRepository(
      ApiClient(const AppConfig(host: '127.0.0.1', port: 1)),
      socket,
      snapshots: store,
    );
  });

  Quote quote(String id, double ltp) => Quote(
    symbol: id,
    ltp: ltp,
    change: 0,
    changePercent: 0,
    lastTradeTime: DateTime.utc(2026, 11, 10, 5),
  );

  test(
    'default watchlist; setWatchlist stores a copy and marks dirty once',
    () async {
      expect(repo.watchlistIds, ['NIFTY', 'RELIANCE', 'HDFCBANK']);
      final emitted = <List<String>>[];
      repo.watchWatchlistIds().listen(emitted.add);
      final ids = ['TCS', 'INFY'];

      repo.setWatchlist(ids);
      ids.add('SBIN');
      await pumpEventQueue();

      expect(repo.watchlistIds, ['TCS', 'INFY']);
      expect(() => repo.watchlistIds.add('X'), throwsUnsupportedError);
      expect(store.structuralDirtyMarks, 1);
      expect(emitted, [
        ['TCS', 'INFY'],
      ]);
    },
  );

  test(
    'seedFromCache → fromCache until a live tick; latestQuotes order',
    () async {
      repo.seedFromCache([quote('TCS', 3000), quote('INFY', 1500)]);
      expect(repo.latest('TCS')!.fromCache, isTrue);
      expect(repo.latestQuotes(['INFY', 'NOPE', 'TCS']).map((q) => q.id), [
        'INFY',
        'TCS',
      ]);

      final live = <List<Quote>>[];
      final sub = repo.watchQuotes(['TCS'], FeedMode.quote).listen(live.add);
      await pumpEventQueue();
      socket.emit({
        'type': 'ticks',
        'seq': 1,
        'data': [
          {'s': 'TCS', 'ltp': 3001.0, 't': 1762750800000},
        ],
      });
      await pumpEventQueue();

      expect(live.first.single.fromCache, isTrue); // cached replay first
      expect(live.last.single.fromCache, isFalse);
      expect(live.last.single.ltp, 3001.0);
      expect(socket.activeQuoteIds, {'TCS'});
      await sub.cancel();
      expect(socket.activeQuoteIds, isEmpty);
    },
  );

  test('Quote == ignores asOf and seq, not fromCache; toJson round-trips', () {
    final a = quote('TCS', 1);
    final b = a.copyWith(asOf: DateTime.utc(2030), seq: 9);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.copyWith(fromCache: true), isNot(a));
    final back = Quote.fromJson(b.toJson());
    expect(back, a);
    expect(back.asOf, DateTime.utc(2030));
  });
}
