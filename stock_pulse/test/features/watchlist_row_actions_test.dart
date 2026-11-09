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
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/market/presentation/screens/watchlist_screen.dart';
import 'package:stock_pulse/features/market/presentation/widgets/watchlist_row_actions.dart';

import '../helpers/fake_analytics_sink.dart';
import '../helpers/fake_crash_reporter.dart';

class _MarketRepository extends Mock implements MarketRepository {}

const _tcs = Instrument(
  symbol: 'TCS',
  name: 'Tata Consultancy Services',
  exchange: 'NSE',
  sector: 'IT',
  tickSize: 0.05,
  lotSize: 1,
);

Quote _quote() => Quote(
  symbol: 'TCS',
  ltp: 3000,
  change: 0,
  changePercent: 0,
  lastTradeTime: DateTime.utc(2026, 11, 8, 12),
);

void main() {
  late _MarketRepository repository;
  late StreamController<List<Quote>> live;

  setUpAll(() => registerFallbackValue(FeedMode.quote));

  setUp(() {
    repository = _MarketRepository();
    live = StreamController<List<Quote>>();
    addTearDown(() => unawaited(live.close()));
    when(() => repository.getInstruments())
        .thenAnswer((_) async => const Success([_tcs]));
    when(() => repository.getQuotes(any()))
        .thenAnswer((_) async => Success([_quote()]));
    when(() => repository.latest(any())).thenReturn(null);
    when(() => repository.watchQuotes(any(), any()))
        .thenAnswer((_) => live.stream);
  });

  testWidgets('equity action sheet includes Buy and Sell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: WatchlistRowActionsSheet(instrument: _tcs)),
      ),
    );
    expect(find.text('BUY'), findsOneWidget);
    expect(find.text('SELL'), findsOneWidget);
  });

  testWidgets('equity actions navigate to order, chart and option chain', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: WatchlistRoute.path,
      routes: [
        GoRoute(
          path: WatchlistRoute.path,
          builder: (_, _) => WatchlistScreen(key: UniqueKey()),
        ),
        GoRoute(
          path: OrderTicketRoute.path,
          builder: (_, state) =>
              Scaffold(body: Text('Order ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: StockRoute.path,
          builder: (_, state) =>
              Scaffold(body: Text('Stock ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: OptionChainRoute.path,
          builder: (_, _) => const Scaffold(body: Text('Options destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    final sink = FakeAnalyticsSink();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marketRepositoryProvider.overrideWithValue(repository),
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

    for (final (action, destination) in [
      ('BUY', 'Order TCS'),
      ('SELL', 'Order TCS'),
      ('Chart', 'Stock TCS'),
      ('Option chain', 'Options destination'),
    ]) {
      await tester.longPress(find.text('TCS').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(action).last);
      await tester.pumpAndSettle();
      expect(find.text(destination), findsOneWidget);
      router.go(WatchlistRoute.path);
      await tester.pumpAndSettle();
    }
    expect(sink.events, hasLength(4));
  });
}
