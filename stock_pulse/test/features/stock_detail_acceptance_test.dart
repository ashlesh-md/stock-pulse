import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/feedback/presentation/feedback_host.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/market/presentation/screens/stock_detail_screen.dart';
import 'package:stock_pulse/features/orders/di/order_preflight_provider.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

import '../helpers/fake_crash_reporter.dart';
import '../helpers/fake_local_prefs.dart';
import '../helpers/fake_pending_order_store.dart';

class MockMarketRepository extends Mock implements MarketRepository {}

class MockPortfolioRepository extends Mock implements PortfolioRepository {}

const tcs = Instrument(
  symbol: 'TCS',
  name: 'Tata Consultancy Services',
  exchange: 'NSE',
  sector: 'IT',
  tickSize: 0.05,
  lotSize: 1,
);

const nifty = Instrument(
  symbol: 'NIFTY',
  name: 'NIFTY 50',
  exchange: 'NSE',
  sector: 'Index',
  tickSize: 0.05,
  lotSize: 1,
  kind: InstrumentKind.marketIndex,
);

Quote quote(double ltp, int t) => Quote.fromJson({
  's': 'TCS',
  'ltp': ltp,
  'ch': ltp - 3000,
  'chp': 0.1,
  't': t,
  'o': 2995.0,
  'h': 3020.0,
  'l': 2990.0,
  'pc': 3000.0,
  'v': 1000,
  'lq': 5,
  'bid': ltp - 0.05,
  'ask': ltp,
  'depth': {
    'bids': [
      {'p': ltp - 0.05, 'q': 120, 'n': 3},
    ],
    'asks': [
      {'p': ltp, 'q': 80, 'n': 2},
    ],
  },
});

void main() {
  setUpAll(() {
    registerFallbackValue(FeedMode.full);
    registerFallbackValue(CandleInterval.m1);
    registerFallbackValue(OrderSide.buy);
    registerFallbackValue(OrderType.market);
  });

  late MockMarketRepository repo;
  late MockPortfolioRepository portfolio;
  late StreamController<List<Quote>> live;
  final start = DateTime.utc(2026, 11, 4, 5);
  final candles = [
    for (var i = 0; i < 30; i++)
      Candle(
        start: start.add(Duration(minutes: i * 5)),
        open: 3000,
        high: 3005,
        low: 2995,
        close: 3001,
        volume: 100,
      ),
  ];

  setUp(() {
    repo = MockMarketRepository();
    portfolio = MockPortfolioRepository();
    live = StreamController<List<Quote>>.broadcast();
    // Not awaited: a single-subscription controller that was never listened
    // to only completes close() once someone listens.
    addTearDown(() => unawaited(live.close()));
    when(() => repo.getInstrument('TCS'))
        .thenAnswer((_) async => const Success(tcs));
    when(() => repo.getInstrument('NIFTY'))
        .thenAnswer((_) async => const Success(nifty));
    when(() => repo.getCandles(any(), any(), from: any(named: 'from')))
        .thenAnswer((_) async => Success(candles));
    when(() => repo.getQuotes(any(), full: true))
        .thenAnswer((_) async => Success([quote(3001, 1000)]));
    when(
      () =>
          repo.watchQuotes(any(), any(), throttleMs: any(named: 'throttleMs')),
    ).thenAnswer((_) => live.stream);
  });

  Widget app({String instrumentId = 'TCS'}) => ProviderScope(
    overrides: [
      crashReporterProvider.overrideWithValue(FakeCrashReporter()),
      orderPreflightProvider.overrideWithValue(
        ({
          required symbol,
          required side,
          required type,
          required product,
          required quantity,
          lots,
          limitPrice,
          triggerPrice,
        }) => null,
      ),
      marketRepositoryProvider.overrideWithValue(repo),
      portfolioRepositoryProvider.overrideWithValue(portfolio),
      fakePendingOrderStoreOverride(),
      localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
      marketClockProvider.overrideWith(
        (ref) => Stream.value(
          MarketClockState.fallback.copyWith(phase: MarketPhase.preOpen),
        ),
      ),
      socketStatusProvider.overrideWith((ref) => const Stream.empty()),
      networkStatusProvider.overrideWith((ref) => const Stream.empty()),
    ],
    retry: (_, _) => null,
    child: MaterialApp(
      theme: AppTheme.dark(),
      builder: (_, child) => FeedbackHost(child: child!),
      home: StockDetailScreen(instrumentId: instrumentId),
    ),
  );

  Future<void> pumpUntilLoaded(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('S-18: index has Pre-open status, no depth or Buy/Sell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(instrumentId: 'NIFTY'));
    await pumpUntilLoaded(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Pre-open'), findsOneWidget);
    expect(find.text('Market depth'), findsNothing);
    expect(find.text('BUY'), findsNothing);
    expect(find.text('SELL'), findsNothing);
    expect(find.text('Options'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('S-18: equity trade actions fit the bottom quarter at 360×800', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await pumpUntilLoaded(tester);

    final price = find.text('₹3,001.00');
    expect(tester.widget<Text>(price).textAlign, TextAlign.left);
    expect(
      tester.getRect(price).left,
      closeTo(tester.getRect(find.textContaining('Last trade')).left, 1),
    );

    for (final label in ['BUY', 'SELL']) {
      final finder = find.widgetWithText(FilledButton, label);
      final rect = tester.getRect(finder);
      expect(rect.height, greaterThanOrEqualTo(48));
      expect(rect.top, greaterThanOrEqualTo(600));
      expect(rect.bottom, lessThanOrEqualTo(800));
      expect(tester.widget<FilledButton>(finder).onPressed, isNotNull);
    }
  });
  testWidgets('error state with Retry, and no trade bar', (tester) async {
    when(() => repo.getQuotes(any(), full: true))
        .thenAnswer((_) async => const Failure(NetworkError()));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.text('Cannot reach the server. Check your connection.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'BUY'), findsNothing);

    when(() => repo.getQuotes(any(), full: true))
        .thenAnswer((_) async => Success([quote(3001, 1000)]));
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'BUY'), findsOneWidget);
  });
}
