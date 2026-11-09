import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/locales/en/order_strings_en.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/application/order_announcer.dart';
import 'package:stock_pulse/features/portfolio/application/order_summary.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_funds_provider.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_section.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';
import 'package:stock_pulse/features/portfolio/presentation/screens/portfolio_screen.dart';

import '../../helpers/fake_crash_reporter.dart';
import '../../helpers/fake_pending_order_store.dart';

class MockPortfolioRepository extends Mock implements PortfolioRepository {}

class MockMarketRepository extends Mock implements MarketRepository {}

final _t = DateTime.utc(2026, 11, 4, 5);

Order order(
  String id,
  OrderStatus status, {
  OrderType type = OrderType.limit,
  OrderSide side = OrderSide.buy,
  String? message,
  Duration after = Duration.zero,
}) => Order(
  id: id,
  symbol: 'TCS',
  side: side,
  type: type,
  quantity: 10,
  status: status,
  limitPrice: type == OrderType.limit ? 3050 : null,
  averagePrice: status == OrderStatus.complete ? 3049.95 : null,
  message: message,
  createdAt: _t,
  updatedAt: _t.add(after),
);

void main() {
  setUpAll(() => registerFallbackValue(FeedMode.ltp));

  late MockPortfolioRepository portfolio;
  late MockMarketRepository market;
  late StreamController<Order> updates;
  late ProviderContainer container;

  setUp(() {
    portfolio = MockPortfolioRepository();
    market = MockMarketRepository();
    updates = StreamController<Order>.broadcast();
    addTearDown(updates.close);
    when(() => portfolio.orderUpdates).thenAnswer((_) => updates.stream);
    when(() => portfolio.getOrders()).thenAnswer(
      (_) async => Success([
        order('O1', OrderStatus.open),
        order('O2', OrderStatus.cancelled, type: OrderType.market),
        order('O3', OrderStatus.rejected, side: OrderSide.sell),
      ]),
    );
    when(() => portfolio.getPositions()).thenAnswer(
      (_) async => const Success([
        Position(
          symbol: 'TCS',
          quantity: -5,
          averagePrice: 3000,
          realizedPnl: 0,
        ),
      ]),
    );
    when(() => market.watchQuotes(any(), any()))
        .thenAnswer((_) => const Stream<List<Quote>>.empty());
    when(() => market.latestQuotes(any())).thenReturn(const []);
    container = ProviderContainer.test(
      overrides: [
        fakePendingOrderStoreOverride(),
        analyticsProvider.overrideWithValue(
          AnalyticsService(const [], FakeCrashReporter(), consent: () => false),
        ),
        portfolioRepositoryProvider.overrideWithValue(portfolio),
        portfolioFundsProvider.overrideWith((ref) => const Stream.empty()),
        marketRepositoryProvider.overrideWithValue(market),
        networkStatusProvider.overrideWith((ref) => const Stream.empty()),
      ],
      retry: (_, _) => null,
    );
  });

  FeedbackMessage? shown() => container.read(feedbackControllerProvider);

  group('orderSummary', () {
    const s = OrderStringsEn();
    test('one line per status, sell and reason included', () {
      expect(
        orderSummary(order('O', OrderStatus.complete), s),
        'BUY 10 TCS filled @ ₹3,049.95',
      );
      expect(
        orderSummary(order('O', OrderStatus.open), s),
        'BUY 10 TCS placed · waiting for ₹3,050.00',
      );
      expect(
        orderSummary(order('O', OrderStatus.rejected, side: OrderSide.sell), s),
        'SELL 10 TCS rejected',
      );
      expect(
        orderSummary(order('O', OrderStatus.rejected, message: 'No funds'), s),
        'BUY 10 TCS rejected: No funds',
      );
    });
  });

  group('PortfolioController', () {
    test('cancel failure shows one error snackbar keyed by order', () async {
      when(() => portfolio.cancelOrder('O1'))
          .thenAnswer((_) async => const Failure(NetworkError()));
      await container.read(portfolioControllerProvider.future);

      await container.read(portfolioControllerProvider.notifier).cancel('O1');

      expect(shown()?.key, 'portfolio.cancelFailed.O1');
      expect(shown()?.kind, FeedbackKind.error);
    });

    test('cancel success shows nothing', () async {
      when(() => portfolio.cancelOrder('O1'))
          .thenAnswer((_) async => Success(order('O1', OrderStatus.cancelled)));
      await container.read(portfolioControllerProvider.future);
      await container.read(portfolioControllerProvider.notifier).cancel('O1');
      expect(shown(), isNull);
    });

    test('an update replaces the order with the same id', () async {
      container.listen(portfolioControllerProvider, (_, _) {});
      await container.read(portfolioControllerProvider.future);
      updates.add(order('O1', OrderStatus.cancelled));
      await pumpEventQueue();
      final orders = container
          .read(portfolioControllerProvider)
          .requireValue
          .orders;
      expect(orders.first.status, OrderStatus.cancelled);
      expect(orders, hasLength(3));
    });

    test('refresh reloads from REST', () async {
      container.listen(portfolioControllerProvider, (_, _) {});
      await container.read(portfolioControllerProvider.future);
      await container.read(portfolioControllerProvider.notifier).refresh();
      verify(() => portfolio.getOrders()).called(2);
    });
  });

  group('OrderAnnouncer', () {
    test('a later rejection persists as an order outcome error', () async {
      container.listen(orderAnnouncerProvider, (_, _) {});
      updates.add(
        order('O9', OrderStatus.rejected, after: const Duration(seconds: 5)),
      );
      await pumpEventQueue();
      expect(shown()?.key, 'orders.rejected.O9');
      expect(shown()?.persist, isTrue);
      expect(shown()?.priority, FeedbackPriority.orderOutcome);
    });

    test('an instant fill and an open order are not announced', () async {
      container.listen(orderAnnouncerProvider, (_, _) {});
      updates
        ..add(order('O1', OrderStatus.complete))
        ..add(order('O2', OrderStatus.open, after: const Duration(seconds: 5)));
      await pumpEventQueue();
      expect(shown(), isNull);
      expect(
        OrderAnnouncer.shouldAnnounce(
          order('O', OrderStatus.cancelled, after: const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });
  });

  testWidgets('PortfolioScreen: short position, order kinds, cancel', (
    tester,
  ) async {
    when(() => portfolio.cancelOrder('O1'))
        .thenAnswer((_) async => Success(order('O1', OrderStatus.cancelled)));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const PortfolioScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Short 5 @ 3,000.00'), findsOneWidget);
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(find.text('TCS × 10  limit 3,050.00'), findsWidgets);
    expect(find.text('TCS × 10  market'), findsOneWidget);
    expect(find.text('cancelled'), findsOneWidget);
    expect(find.text('rejected'), findsOneWidget);
    expect(find.text('SELL'), findsOneWidget);
    expect(find.textContaining('O2 · Market'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verify(() => portfolio.cancelOrder('O1')).called(1);
  });

  testWidgets('PortfolioScreen loads and renders the empty holdings section', (
    tester,
  ) async {
    when(() => portfolio.getHoldings())
        .thenAnswer((_) async => const Success([]));
    when(() => portfolio.watchHoldings())
        .thenAnswer((_) => const Stream.empty());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const PortfolioScreen(
            initialSection: PortfolioSection.holdings,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No delivery holdings yet.'), findsOneWidget);
    verify(() => portfolio.getHoldings()).called(1);
  });

  testWidgets('PortfolioScreen offers retry when holdings fail to load', (
    tester,
  ) async {
    when(() => portfolio.getHoldings())
        .thenAnswer((_) async => const Failure(NetworkError()));
    when(() => portfolio.watchHoldings())
        .thenAnswer((_) => const Stream.empty());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const PortfolioScreen(
            initialSection: PortfolioSection.holdings,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Holdings could not be loaded'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    verify(() => portfolio.getHoldings()).called(2);
  });
}
