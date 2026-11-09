import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_repository.dart';
import 'package:stock_pulse/features/orders/domain/order_request.dart';
import 'package:stock_pulse/features/orders/domain/place_outcome.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

import '../helpers/fake_crash_reporter.dart';
import '../helpers/fake_local_prefs.dart';
import '../helpers/fake_pending_order_store.dart';

class MockMarketRepository extends Mock implements MarketRepository {}

class MockPortfolioRepository extends Mock implements PortfolioRepository {}

class MockOrderRepository extends Mock implements OrderRepository {}

const tcs = Instrument(
  symbol: 'TCS',
  name: 'Tata Consultancy Services',
  exchange: 'NSE',
  sector: 'IT',
  tickSize: 0.05,
  lotSize: 1,
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
    registerFallbackValue(
      const OrderRequest(
        symbol: 'TCS',
        side: OrderSide.buy,
        type: OrderType.market,
        product: ProductType.cnc,
        quantity: 1,
      ),
    );
  });

  late MockMarketRepository repo;
  late MockPortfolioRepository portfolio;
  late MockOrderRepository orders;
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
    orders = MockOrderRepository();
    live = StreamController<List<Quote>>.broadcast();
    // Not awaited: a single-subscription controller that was never listened
    // to only completes close() once someone listens.
    addTearDown(() => unawaited(live.close()));
    when(() => repo.getInstrument('TCS'))
        .thenAnswer((_) async => const Success(tcs));
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
      orderRepositoryProvider.overrideWithValue(orders),
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

  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  void whenPlaceOrder(Future<PlaceOutcome> Function() answer) => when(
    () => orders.place(any(), idempotencyKey: any(named: 'idempotencyKey')),
  ).thenAnswer((_) => answer());

  Finder sheetBuyButton() => find.descendant(
    of: find.byType(BottomSheet),
    matching: find.widgetWithText(FilledButton, 'BUY 1 TCS'),
  );

  testWidgets('a rejection shows its reason ON the sheet, which stays open', (
    tester,
  ) async {
    tallScreen(tester);
    whenPlaceOrder(
      () async => const PlaceRejected(
        'price_out_of_band',
        'Price is outside the 20% band',
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'BUY'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.tap(sheetBuyButton());
    await tester.pumpAndSettle();

    final message = find.text(
      'Order not placed: the price is more than 20% away from the previous '
      'close',
    );
    expect(find.text('Price is outside the 20% band'), findsNothing);
    expect(
      find.descendant(of: find.byType(BottomSheet), matching: message),
      findsOneWidget,
    );
    expect(
      find.text('Quantity'),
      findsOneWidget,
      reason: 'form still open to fix the input',
    );
  });

  testWidgets('a filled order closes the sheet and confirms on the page', (
    tester,
  ) async {
    tallScreen(tester);
    final now = DateTime.utc(2026, 11, 4, 5);
    whenPlaceOrder(
      () async => PlaceAcked(
        Order(
          id: 'ORD000007',
          symbol: 'TCS',
          side: OrderSide.buy,
          type: OrderType.market,
          quantity: 1,
          status: OrderStatus.complete,
          averagePrice: 3001,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'BUY'));
    await tester.pumpAndSettle();
    await tester.tap(sheetBuyButton());
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(
      find.text('ORD000007: BUY 1 TCS filled @ ₹3,001.00'),
      findsOneWidget,
    );
  });
}
