import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_funds_provider.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_book.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';
import 'package:stock_pulse/features/portfolio/presentation/screens/portfolio_screen.dart';

import '../helpers/fake_pending_order_store.dart';

class MockPortfolioRepository extends Mock implements PortfolioRepository {}

class MockMarketRepository extends Mock implements MarketRepository {}

final _t = DateTime.utc(2026, 11, 4, 5);

Order order(String id, OrderStatus status) => Order(
  id: id,
  symbol: 'TCS',
  side: OrderSide.buy,
  type: OrderType.market,
  quantity: 10,
  status: status,
  averagePrice: 3000,
  createdAt: _t,
  updatedAt: _t,
);

Position position(int qty) =>
    Position(symbol: 'TCS', quantity: qty, averagePrice: 3000, realizedPnl: 0);

void main() {
  setUpAll(() => registerFallbackValue(FeedMode.ltp));

  late MockPortfolioRepository portfolio;
  late MockMarketRepository market;
  late StreamController<Order> updates;
  late StreamController<List<Quote>> prices;

  setUp(() {
    portfolio = MockPortfolioRepository();
    market = MockMarketRepository();
    updates = StreamController<Order>.broadcast();
    prices = StreamController<List<Quote>>.broadcast();
    addTearDown(updates.close);
    addTearDown(prices.close);
    when(() => portfolio.orderUpdates).thenAnswer((_) => updates.stream);
    when(
      () => portfolio.getOrders(),
    ).thenAnswer((_) async => Success([order('ORD1', OrderStatus.complete)]));
    when(() => portfolio.getPositions())
        .thenAnswer((_) async => Success([position(10)]));
    when(() => market.watchQuotes(any(), any()))
        .thenAnswer((_) => prices.stream);
    when(() => market.latestQuotes(any())).thenReturn(const []);
  });

  List<Override> fakes() => [
    fakePendingOrderStoreOverride(),
    portfolioRepositoryProvider.overrideWithValue(portfolio),
    portfolioFundsProvider.overrideWith((ref) => const Stream.empty()),
    marketRepositoryProvider.overrideWithValue(market),
    socketStatusProvider.overrideWith((ref) => const Stream.empty()),
    networkStatusProvider.overrideWith((ref) => const Stream.empty()),
  ];

  group('PortfolioController', () {
    test(
      'failed positions fall back to the cached book; holdings stream in',
      () async {
        final holdings = StreamController<List<Holding>>.broadcast();
        addTearDown(holdings.close);
        when(() => portfolio.getPositions())
            .thenAnswer((_) async => const Failure(NetworkError()));
        when(() => portfolio.current).thenReturn(
          PortfolioBook(positions: [position(7)], holdings: const []),
        );
        when(() => portfolio.getHoldings())
            .thenAnswer((_) async => const Success([]));
        when(() => portfolio.watchHoldings())
            .thenAnswer((_) => holdings.stream);
        final container = ProviderContainer(
          overrides: fakes(),
          retry: (_, _) => null,
        );
        addTearDown(container.dispose);
        container.listen(portfolioControllerProvider, (_, _) {});
        final loaded = await container.read(portfolioControllerProvider.future);
        expect(loaded.positions.single.quantity, 7);

        await container
            .read(portfolioControllerProvider.notifier)
            .loadHoldings();
        holdings.add(const [
          Holding(symbol: 'TCS', quantity: 2, averagePrice: 1),
        ]);
        await pumpEventQueue();
        expect(
          container
              .read(portfolioControllerProvider)
              .requireValue
              .holdings
              .single
              .symbol,
          'TCS',
        );
      },
    );

    test(
      'two quick fills: the OLDER positions answer arriving last is ignored',
      () async {
        final container = ProviderContainer(
          overrides: fakes(),
          retry: (_, _) => null,
        );
        addTearDown(container.dispose);
        container.listen(portfolioControllerProvider, (_, _) {});
        await container.read(portfolioControllerProvider.future);

        final first = Completer<Result<List<Position>>>();
        final second = Completer<Result<List<Position>>>();
        final answers = [first, second];
        when(() => portfolio.getPositions())
            .thenAnswer((_) => answers.removeAt(0).future);

        updates.add(order('ORD2', OrderStatus.complete)); // reload #1 starts
        await pumpEventQueue();
        updates.add(order('ORD3', OrderStatus.complete)); // reload #2 starts
        await pumpEventQueue();

        second.complete(Success([position(30)])); // newest answer first
        await pumpEventQueue();
        first.complete(Success([position(20)])); // stale answer last
        await pumpEventQueue();

        final state = container.read(portfolioControllerProvider).requireValue;
        expect(state.positions.single.quantity, 30);
        expect(state.orders.map((o) => o.id), ['ORD3', 'ORD2', 'ORD1']);
      },
    );

    test('live prices give unrealised P&L', () async {
      final container = ProviderContainer(
        overrides: fakes(),
        retry: (_, _) => null,
      );
      addTearDown(container.dispose);
      container.listen(portfolioControllerProvider, (_, _) {});
      await container.read(portfolioControllerProvider.future);

      prices.add([
        Quote.fromJson({'s': 'TCS', 'ltp': 3012.5, 'ch': 0, 'chp': 0, 't': 1}),
      ]);
      await pumpEventQueue();

      expect(
        container.read(portfolioControllerProvider).requireValue.unrealizedPnl,
        125,
      ); // 12.5 × 10
    });
  });

  group('PortfolioScreen', () {
    Widget app() => ProviderScope(
      overrides: fakes(),
      retry: (_, _) => null,
      child: MaterialApp(theme: AppTheme.dark(), home: const PortfolioScreen()),
    );

    testWidgets('loading → positions, orders and live P&L', (tester) async {
      await tester.pumpWidget(app());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('Positions (1)'), findsOneWidget);
      expect(find.text('Long 10 @ 3,000.00'), findsOneWidget);
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      expect(find.text('Orders (1)'), findsOneWidget);
      await tester.tap(find.text('Positions'));
      await tester.pumpAndSettle();

      prices.add([
        Quote.fromJson({'s': 'TCS', 'ltp': 2990.0, 'ch': 0, 'chp': 0, 't': 1}),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('-100.00'), findsWidgets); // row and card
    });

    testWidgets('an order filled over the socket appears without a refresh', (
      tester,
    ) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      updates.add(order('ORD9', OrderStatus.open));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      expect(find.text('Orders (2)'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    });

    testWidgets('error state with Retry', (tester) async {
      when(() => portfolio.getOrders())
          .thenAnswer((_) async => const Failure(NetworkError()));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(
        find.text('Cannot reach the server. Check your connection.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    });
  });
}
