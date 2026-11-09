import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

import '../../helpers/fake_local_prefs.dart';

class Repo extends Mock implements MarketRepository {}

const a = Instrument(
  symbol: 'A',
  name: 'A',
  exchange: 'NSE',
  sector: '',
  tickSize: .05,
  lotSize: 1,
);
const b = Instrument(
  symbol: 'B',
  name: 'B',
  exchange: 'NSE',
  sector: '',
  tickSize: .05,
  lotSize: 1,
);

void main() {
  setUpAll(() => registerFallbackValue(FeedMode.quote));
  late Repo repo;
  late FakeLocalPrefs prefs;
  late ProviderContainer container;
  setUp(() {
    repo = Repo();
    prefs = FakeLocalPrefs();
    when(() => repo.getInstruments())
        .thenAnswer((_) async => const Success([a, b]));
    when(() => repo.getQuotes(any()))
        .thenAnswer((_) async => const Success([]));
    when(() => repo.watchQuotes(any(), any()))
        .thenAnswer((_) => const Stream.empty());
    container = ProviderContainer.test(
      overrides: [
        marketRepositoryProvider.overrideWithValue(repo),
        localPrefsProvider.overrideWith((ref) async => prefs),
      ],
    );
    container.listen(watchlistControllerProvider, (_, _) {});
  });
  test('pin and reorder update state and persist device preferences', () async {
    await container.read(watchlistControllerProvider.future);
    final controller = container.read(watchlistControllerProvider.notifier);
    await controller.toggleFavourite('B');
    expect(
      container
          .read(watchlistControllerProvider)
          .requireValue
          .orderedInstruments
          .first
          .id,
      'B',
    );
    expect(prefs.data.favouriteIds, {'B'});
    await controller.toggleFavourite('B');
    await controller.reorder(0, 1);
    expect(prefs.data.watchlistOrder, ['B', 'A']);
    expect(prefs.data.favouriteIds, isEmpty);
    await controller.reorder(-1, 8);
    expect(prefs.updates, 3);
  });
  test('offline cache is shown when the REST quote load fails', () async {
    final cached = Quote.fromJson({
      's': 'A',
      'ltp': 100,
      'ch': 0,
      'chp': 0,
      't': 1,
    }).copyWith(fromCache: true);
    when(() => repo.getQuotes(any()))
        .thenAnswer((_) async => const Failure(NetworkError()));
    when(() => repo.latestQuotes(any())).thenReturn([cached]);
    container.invalidate(watchlistControllerProvider);
    final state = await container.read(watchlistControllerProvider.future);
    expect(state.quotes['A']?.fromCache, isTrue);
  });
  test(
    'closing during instruments load never starts a live subscription',
    () async {
      final loading = Completer<Result<List<Instrument>>>();
      when(() => repo.getInstruments()).thenAnswer((_) => loading.future);
      container.invalidate(watchlistControllerProvider);
      container.read(watchlistControllerProvider);
      container.dispose();
      loading.complete(const Success([a]));
      await Future<void>.delayed(Duration.zero);
      verifyNever(() => repo.watchQuotes(any(), any()));
    },
  );

  test('saved favourites that load after the list are applied to it', () async {
    final pending = Completer<FakeLocalPrefs>();
    final c = ProviderContainer.test(
      overrides: [
        marketRepositoryProvider.overrideWithValue(repo),
        localPrefsProvider.overrideWith((ref) => pending.future),
      ],
    );
    c.listen(watchlistControllerProvider, (_, _) {});
    await c.read(watchlistControllerProvider.future);
    pending.complete(
      FakeLocalPrefs(
        prefs.data.copyWith(favouriteIds: {'B'}, watchlistOrder: ['B', 'A']),
      ),
    );
    await c.pump();
    await Future<void>.delayed(Duration.zero);
    final state = c.read(watchlistControllerProvider).requireValue;
    expect(state.favouriteIds, {'B'});
    expect(state.orderedInstruments.first.id, 'B');
  });
}
