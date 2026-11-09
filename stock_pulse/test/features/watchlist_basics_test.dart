import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/market/presentation/screens/watchlist_screen.dart';

import '../helpers/fake_local_prefs.dart';

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

Quote quoteAt(String symbol, DateTime asOf, {double ltp = 3000}) => Quote(
  symbol: symbol,
  ltp: ltp,
  change: ltp - 3000,
  changePercent: (ltp - 3000) / 30,
  lastTradeTime: asOf,
  asOf: asOf,
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

  testWidgets('shows the REST snapshot, then live prices', (tester) async {
    await tester.pumpWidget(app());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('TCS'), findsOneWidget);
    expect(find.text('3,000.00'), findsOneWidget);

    live.add([quote(3012.5)]);
    await tester.pumpAndSettle();
    expect(find.text('3,012.50'), findsOneWidget);
    expect(find.textContaining('+12.50'), findsOneWidget);
  });

  testWidgets('shows an error with Retry when REST fails', (tester) async {
    when(() => repo.getInstruments())
        .thenAnswer((_) async => const Failure(NetworkError()));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.text('Cannot reach the server. Check your connection.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

    when(() => repo.getInstruments())
        .thenAnswer((_) async => const Success([tcs]));
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.text('TCS'), findsOneWidget);
  });

  testWidgets('a row without a quote shows a dash; a tap opens the stock', (
    tester,
  ) async {
    const infy = Instrument(
      symbol: 'INFY',
      name: 'Infosys',
      exchange: 'NSE',
      sector: 'IT',
      tickSize: 0.05,
      lotSize: 1,
    );
    when(() => repo.getInstruments())
        .thenAnswer((_) async => const Success([tcs, infy]));
    final router = GoRouter(
      initialLocation: WatchlistRoute.path,
      routes: [
        GoRoute(
          path: WatchlistRoute.path,
          name: WatchlistRoute.name,
          builder: (_, _) => const WatchlistScreen(),
        ),
        GoRoute(
          path: StockRoute.path,
          name: StockRoute.name,
          builder: (_, state) => Text('stock ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketRepositoryProvider.overrideWithValue(repo),
          socketStatusProvider.overrideWith((ref) => const Stream.empty()),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
        ],
        retry: (_, _) => null,
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('—'), findsOneWidget);

    await tester.tap(find.text('TCS'));
    await tester.pumpAndSettle();
    expect(find.text('stock TCS'), findsOneWidget);
  });

  testWidgets('CR-2 #13: the star pins a stock and then unpins it', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketRepositoryProvider.overrideWithValue(repo),
          socketStatusProvider.overrideWith((ref) => const Stream.empty()),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
          localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
        ],
        retry: (_, _) => null,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const WatchlistScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Pin favourite'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Unpin favourite'), findsOneWidget);
    await tester.tap(find.byTooltip('Unpin favourite'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Pin favourite'), findsOneWidget);
  });

  testWidgets('CR-2 #13: dragging a handle reorders the rows', (tester) async {
    const infy = Instrument(
      symbol: 'INFY',
      name: 'Infosys',
      exchange: 'NSE',
      sector: 'IT',
      tickSize: 0.05,
      lotSize: 1,
    );
    when(() => repo.getInstruments())
        .thenAnswer((_) async => const Success([tcs, infy]));
    final prefs = FakeLocalPrefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketRepositoryProvider.overrideWithValue(repo),
          socketStatusProvider.overrideWith((ref) => const Stream.empty()),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
          localPrefsProvider.overrideWith((ref) async => prefs),
        ],
        retry: (_, _) => null,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const WatchlistScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pump();
    final handle = find.byIcon(AppIcons.reorder).first;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(prefs.data.watchlistOrder, ['INFY', 'TCS']);
  });

  testWidgets('B15: reorder handles show only in Edit mode; the star stays', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.reorder), findsNothing);
    expect(find.byTooltip('Pin favourite'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pump();
    expect(find.byIcon(AppIcons.reorder), findsOneWidget);
    expect(find.byTooltip('Pin favourite'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(find.byIcon(AppIcons.reorder), findsNothing);
  });

  testWidgets('B15: no Edit button while the list is loading', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('Edit'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
  });
}
