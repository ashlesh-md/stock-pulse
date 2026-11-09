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
import 'package:stock_pulse/features/chart/di/chart_studies_providers.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/chart/domain/studies_store.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/market/presentation/screens/stock_detail_screen.dart';
import 'package:stock_pulse/features/market/presentation/widgets/stock_chart_toolbar.dart';
import 'package:stock_pulse/features/orders/domain/order.dart'
    show OrderSide, OrderType;
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

import '../../helpers/fake_crash_reporter.dart';
import '../../helpers/fake_local_prefs.dart';
import '../../helpers/fake_pending_order_store.dart';

class MockMarketRepository extends Mock implements MarketRepository {}

class MockPortfolioRepository extends Mock implements PortfolioRepository {}

class _Studies implements StudiesStore {
  @override
  Future<List<StudySpec>> read(String instrumentId) async => const [];
  @override
  Future<void> write(String instrumentId, List<StudySpec> studies) async {}
}

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
    addTearDown(live.close);
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

  Widget app([String instrumentId = 'TCS']) => ProviderScope(
    overrides: [
      crashReporterProvider.overrideWithValue(FakeCrashReporter()),
      marketRepositoryProvider.overrideWithValue(repo),
      marketClockProvider.overrideWith(
        (ref) => Stream.value(MarketClockState.fallback),
      ),
      portfolioRepositoryProvider.overrideWithValue(portfolio),
      fakePendingOrderStoreOverride(),
      localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
      socketStatusProvider.overrideWith((ref) => const Stream.empty()),
      networkStatusProvider.overrideWith((ref) => const Stream.empty()),
      studiesStoreProvider.overrideWithValue(_Studies()),
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

  testWidgets('a failed range keeps the old chart and flags it', (
    tester,
  ) async {
    tallScreen(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final slow = Completer<Result<List<Candle>>>();
    when(() => repo.getCandles(any(), any(), from: any(named: 'from')))
        .thenAnswer((_) => slow.future);
    await tester.tap(find.widgetWithText(TextButton, '1Y'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    slow.complete(const Failure(NetworkError()));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Could not load this chart. Pick it again.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextButton, '1D'), findsOneWidget);
  });

  testWidgets('chart toolbar height stays fixed as live values change', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final toolbar = find.byType(StockChartToolbar);
    final initialHeight = tester.getSize(toolbar).height;
    live.add([
      quote(10000.12, DateTime.utc(2026, 11, 8, 12).millisecondsSinceEpoch),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getSize(toolbar).height, initialHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart toolbar wraps controls cleanly on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    final toolbar = find.byType(StockChartToolbar);
    await tester.ensureVisible(toolbar);
    await tester.pumpAndSettle();

    final toolbarRect = tester.getRect(toolbar);
    final intervalRect = tester.getRect(find.byTooltip('Candle interval'));
    final styleRect = tester.getRect(find.byTooltip('Chart type'));
    expect(toolbarRect.width, 390);
    expect(intervalRect.overlaps(styleRect), isFalse);
    expect(intervalRect.right, lessThanOrEqualTo(toolbarRect.right));
    expect(styleRect.right, lessThanOrEqualTo(toolbarRect.right));
    expect(toolbarRect.height, greaterThan(60));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the interval menu lists the range intervals', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Candle interval'));
    await tester.pumpAndSettle();
    expect(find.text('1m  ·  1 candle = 1 minute'), findsOneWidget);
    await tester.tap(find.text('15m  ·  1 candle = 1 15 minutes'));
    await tester.pumpAndSettle();
    expect(find.text('15m'), findsOneWidget);
  });

  testWidgets('SELL opens the sheet; limit and validation messages', (
    tester,
  ) async {
    tallScreen(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'SELL'));
    await tester.pumpAndSettle();
    expect(find.text('Fills now at the best bid price.'), findsOneWidget);

    await tester.tap(find.byTooltip('Order type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limit').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Fills when someone buys at this price or higher.'),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<OrderSide>),
        matching: find.text('BUY'),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Fills when someone sells at this price or lower.'),
      findsOneWidget,
    );

    await tester.enterText(find.widgetWithText(TextField, 'Quantity'), '0');
    await tester.enterText(
      find.widgetWithText(TextField, 'Limit price'),
      '3001.03',
    );
    await tester.pump();
    expect(find.text('Enter a whole number above 0'), findsOneWidget);
    expect(
      find.text('Price must be a multiple of the tick size'),
      findsOneWidget,
    );
    expect(find.text('Fix the highlighted fields to continue'), findsOneWidget);
    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'BUY 0 TCS'),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets('the studies button opens the studies sheet', (tester) async {
    tallScreen(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Studies'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  });
}
