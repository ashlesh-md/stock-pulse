import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/widgets/sp_price_cell.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/market/presentation/screens/watchlist_screen.dart';

class _MarketRepository extends Mock implements MarketRepository {}

const _tcs = Instrument(
  symbol: 'TCS',
  name: 'Tata Consultancy Services',
  exchange: 'NSE',
  sector: 'IT',
  tickSize: 0.05,
  lotSize: 1,
);

Quote _quote(DateTime asOf, {bool fromCache = false, double ltp = 3000}) =>
    Quote(
      symbol: 'TCS',
      ltp: ltp,
      change: 0,
      changePercent: 0,
      lastTradeTime: asOf,
      asOf: asOf,
      fromCache: fromCache,
    );

void main() {
  late _MarketRepository repository;
  late StreamController<List<Quote>> live;
  late Quote? latest;

  setUpAll(() => registerFallbackValue(FeedMode.quote));

  setUp(() {
    repository = _MarketRepository();
    live = StreamController<List<Quote>>();
    latest = null;
    addTearDown(() => unawaited(live.close()));
    when(() => repository.getInstruments())
        .thenAnswer((_) async => const Success([_tcs]));
    when(() => repository.getQuotes(any())).thenAnswer(
      (_) async =>
          Success([_quote(DateTime.utc(2026, 11, 8, 12), fromCache: true)]),
    );
    when(() => repository.latest('TCS')).thenAnswer((_) => latest);
    when(() => repository.watchQuotes(any(), any()))
        .thenAnswer((_) => live.stream);
  });

  Widget app(FakeClock clock) => ProviderScope(
    overrides: [
      marketRepositoryProvider.overrideWithValue(repository),
      socketStatusProvider.overrideWith((ref) => const Stream.empty()),
      networkStatusProvider.overrideWith((ref) => const Stream.empty()),
      clockProvider.overrideWithValue(clock),
    ],
    retry: (_, _) => null,
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: WatchlistScreen(key: UniqueKey()),
    ),
  );

  SpPriceCell price(WidgetTester tester) => tester.widget<SpPriceCell>(
    find.descendant(
      of: find.ancestor(of: find.text('TCS'), matching: find.byType(ListTile)),
      matching: find.byType(SpPriceCell),
    ),
  );

  testWidgets('cached quote remains visibly stale before live confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(app(FakeClock(DateTime.utc(2026, 11, 8, 12))));
    await tester.pumpAndSettle();
    expect(price(tester).isStale, isTrue);
  });

  testWidgets('newer live confirmation makes the cached quote fresh', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 11, 8, 12);
    latest = _quote(now.add(const Duration(seconds: 1)), ltp: 3001);
    await tester.pumpWidget(app(FakeClock(now)));
    await tester.pumpAndSettle();
    expect(price(tester).isStale, isFalse);
  });
}
