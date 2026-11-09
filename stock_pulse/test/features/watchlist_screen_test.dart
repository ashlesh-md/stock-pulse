import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
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
import 'package:stock_pulse/features/market/presentation/widgets/quote_tile.dart';

import '../helpers/build_counter.dart';
import '../helpers/fake_analytics_sink.dart';
import '../helpers/fake_crash_reporter.dart';

class MockMarketRepository extends Mock implements MarketRepository {}

const tcs = Instrument(
  symbol: 'TCS',
  name: 'Tata Consultancy Services',
  exchange: 'NSE',
  sector: 'IT',
  tickSize: 0.05,
  lotSize: 1,
);

Quote quote(double ltp) => Quote.fromJson({
  's': 'TCS',
  'ltp': ltp,
  'ch': ltp - 3000,
  'chp': (ltp - 3000) / 30,
  't': 1,
});

Instrument instrument(
  String symbol, {
  InstrumentKind kind = InstrumentKind.equity,
}) => Instrument(
  symbol: symbol,
  name: symbol,
  exchange: 'NSE',
  sector: 'Test',
  tickSize: 0.05,
  lotSize: 1,
  kind: kind,
);

Quote quoteAt(
  String symbol,
  DateTime asOf, {
  double ltp = 3000,
  bool fromCache = false,
}) => Quote(
  symbol: symbol,
  ltp: ltp,
  change: ltp - 3000,
  changePercent: (ltp - 3000) / 30,
  lastTradeTime: asOf,
  asOf: asOf,
  fromCache: fromCache,
);

void main() {
  setUpAll(() => registerFallbackValue(FeedMode.quote));

  late MockMarketRepository repo;
  late StreamController<List<Quote>> live;
  final latestQuotes = <String, Quote>{};

  setUp(() {
    repo = MockMarketRepository();
    latestQuotes.clear();
    live = StreamController<List<Quote>>();
    // Not awaited: a single-subscription controller that was never listened
    // to only completes close() once someone listens.
    addTearDown(() => unawaited(live.close()));
    when(() => repo.getInstruments())
        .thenAnswer((_) async => const Success([tcs]));
    when(() => repo.getQuotes(any()))
        .thenAnswer((_) async => Success([quote(3000)]));
    when(() => repo.latest(any())).thenAnswer(
      (invocation) =>
          latestQuotes[invocation.positionalArguments.single as String],
    );
    when(() => repo.watchQuotes(any(), any())).thenAnswer((_) => live.stream);
  });

  Widget app() => ProviderScope(
    overrides: [
      marketRepositoryProvider.overrideWithValue(repo),
      // No real socket in widget tests: the status chip just shows "Connecting…".
      socketStatusProvider.overrideWith((ref) => const Stream.empty()),
      networkStatusProvider.overrideWith((ref) => const Stream.empty()),
    ],
    retry: (_, _) => null,
    child: MaterialApp(theme: AppTheme.dark(), home: const WatchlistScreen()),
  );

  testWidgets('S-17 AC1: one live quote rebuilds only its row among 50', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final instruments = [for (var i = 0; i < 50; i++) instrument('S$i')];
    final now = DateTime.now();
    when(() => repo.getInstruments())
        .thenAnswer((_) async => Success(instruments));
    when(() => repo.getQuotes(any())).thenAnswer(
      (_) async =>
          Success([for (final item in instruments) quoteAt(item.id, now)]),
    );
    final counter = BuildCounter.attach();
    addTearDown(counter.detach);

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(QuoteTile), findsNWidgets(50));
    counter.reset();

    live.add([quoteAt('S25', now.add(const Duration(seconds: 1)), ltp: 3001)]);
    await tester.pumpAndSettle();

    expect(counter.ofKey(const ValueKey('S25')), 1);
    expect(counter.ofKey(const ValueKey('S24')), 0);
    expect(counter.ofKey(const ValueKey('S26')), 0);
  });

  testWidgets('S-17 AC2: only the quote older than five seconds turns stale', (
    tester,
  ) async {
    final start = DateTime.utc(2026, 11, 8, 12);
    final clock = FakeClock(start);
    final items = [instrument('RELIANCE'), instrument('TCS')];
    final reliance = quoteAt('RELIANCE', start);
    final tcs = quoteAt(
      'TCS',
      start.add(const Duration(seconds: 4)),
      ltp: 3100,
    );
    latestQuotes.addAll({'RELIANCE': reliance, 'TCS': tcs});
    when(() => repo.getInstruments()).thenAnswer((_) async => Success(items));
    when(() => repo.getQuotes(any()))
        .thenAnswer((_) async => Success([reliance, tcs]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketRepositoryProvider.overrideWithValue(repo),
          socketStatusProvider.overrideWith((ref) => const Stream.empty()),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
          clockProvider.overrideWithValue(clock),
        ],
        retry: (_, _) => null,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const WatchlistScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    clock.advance(const Duration(milliseconds: 5100));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    SpPriceCell priceFor(String symbol) => tester.widget<SpPriceCell>(
      find.descendant(
        of: find.ancestor(
          of: find.text(symbol),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(SpPriceCell),
      ),
    );
    expect(priceFor('RELIANCE').isStale, isTrue);
    expect(priceFor('TCS').isStale, isFalse);
  });

  testWidgets('S-17 AC2: NIFTY row actions omit Buy and Sell', (tester) async {
    final nifty = instrument('NIFTY', kind: InstrumentKind.marketIndex);
    when(() => repo.getInstruments()).thenAnswer((_) async => Success([nifty]));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketRepositoryProvider.overrideWithValue(repo),
          socketStatusProvider.overrideWith((ref) => const Stream.empty()),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
        ],
        retry: (_, _) => null,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const WatchlistScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('NIFTY'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListTile),
      ),
      findsNWidgets(3),
    );
    expect(find.text('Chart'), findsOneWidget);
    expect(find.text('Option chain'), findsOneWidget);
    expect(find.text('Set alert'), findsOneWidget);
    expect(find.text('BUY'), findsNothing);
    expect(find.text('SELL'), findsNothing);
  });

  testWidgets('S-60 logs one action after an index row action is selected', (
    tester,
  ) async {
    const nifty = Instrument(
      symbol: 'NIFTY',
      name: 'NIFTY 50',
      exchange: 'NSE',
      sector: 'Index',
      tickSize: 0.05,
      lotSize: 1,
      kind: InstrumentKind.marketIndex,
    );
    final sink = FakeAnalyticsSink();
    final router = GoRouter(
      initialLocation: WatchlistRoute.path,
      routes: [
        GoRoute(
          path: WatchlistRoute.path,
          name: WatchlistRoute.name,
          builder: (_, _) => const WatchlistScreen(),
        ),
        GoRoute(
          path: AlertsRoute.path,
          name: AlertsRoute.name,
          builder: (_, _) => const Scaffold(body: Text('Alerts destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    when(() => repo.getInstruments())
        .thenAnswer((_) async => const Success([nifty]));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketRepositoryProvider.overrideWithValue(repo),
          analyticsProvider.overrideWithValue(
            AnalyticsService([sink], FakeCrashReporter(), consent: () => true),
          ),
          socketStatusProvider.overrideWith((ref) => const Stream.empty()),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
        ],
        retry: (_, _) => null,
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.longPress(find.text('NIFTY'));
    await tester.pumpAndSettle();
    expect(find.text('BUY'), findsNothing);
    expect(find.text('SELL'), findsNothing);
    await tester.tap(find.text('Set alert'));
    await tester.pumpAndSettle();

    expect(find.text('Alerts destination'), findsOneWidget);
    expect(sink.events, hasLength(1));
    expect(sink.events.single.name, 'watchlist_row_action');
    expect(sink.events.single.params, {
      'action': 'setAlert',
      'instrument_kind': 'marketIndex',
    });
  });
}
