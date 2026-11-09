import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_controller.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_funds_provider.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_state.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_section.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';
import 'package:stock_pulse/features/portfolio/presentation/screens/portfolio_screen.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/portfolio_list.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/position_detail_sheet.dart';

class _Portfolio extends PortfolioController {
  int refreshes = 0;
  int holdingLoads = 0;
  List<Position> positions = const [];
  List<Order> orders = const [];
  final statusChecks = <Order>[];

  @override
  Future<PortfolioState> build() async => PortfolioState(
    orders: orders,
    positions: positions,
    quotes: {
      'INFY': Quote(
        symbol: 'INFY',
        ltp: 1600,
        change: 10,
        changePercent: .63,
        lastTradeTime: DateTime.utc(2026, 11, 10, 5),
      ),
    },
    ltp: const {'INFY': 1600, 'RELIANCE': 110},
  );

  @override
  Future<void> refresh() async => refreshes++;

  @override
  Future<void> refreshPendingStatus(Order pending) async =>
      statusChecks.add(pending);

  @override
  Future<void> loadHoldings() async {
    holdingLoads++;
    state = AsyncData(state.requireValue.copyWith(loadingHoldings: true));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = AsyncData(
      state.requireValue.copyWith(
        loadingHoldings: false,
        holdings: const [
          Holding(symbol: 'INFY', quantity: 5, averagePrice: 1500),
        ],
      ),
    );
  }
}

void main() {
  late _Portfolio controller;

  test('offline scroll physics blocks only overscroll', () {
    const physics = NoOverscrollScrollPhysics();
    final metrics = FixedScrollMetrics(
      minScrollExtent: 0,
      maxScrollExtent: 100,
      pixels: 50,
      viewportDimension: 100,
      axisDirection: AxisDirection.down,
      devicePixelRatio: 1,
    );

    expect(
      physics.applyTo(const ClampingScrollPhysics()),
      isA<NoOverscrollScrollPhysics>(),
    );
    expect(physics.applyBoundaryConditions(metrics, -10), -10);
    expect(physics.applyBoundaryConditions(metrics, 110), 10);
    expect(physics.applyBoundaryConditions(metrics, 60), 0);
  });

  Widget app(PortfolioSection section, {bool offline = false}) => ProviderScope(
    retry: (_, _) => null,
    overrides: [
      portfolioControllerProvider.overrideWith(() => controller),
      portfolioFundsProvider.overrideWith(
        (ref) => Stream.value(const Funds(available: 5000, version: 1)),
      ),
      networkStatusProvider.overrideWith(
        (ref) => offline
            ? Stream.value(NetworkStatus.offline)
            : const Stream.empty(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: PortfolioScreen(initialSection: section),
    ),
  );

  setUp(() => controller = _Portfolio());

  testWidgets('holdings load with a spinner, then rows open the detail sheet', (
    tester,
  ) async {
    await tester.pumpWidget(app(PortfolioSection.holdings));
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(controller.holdingLoads, 1);
    expect(find.text('INFY'), findsOneWidget);
    await tester.tap(find.text('INFY'));
    await tester.pumpAndSettle();
    expect(find.byType(PositionDetailSheet), findsOneWidget);
    expect(find.text('+500.00 (+6.67%)'), findsOneWidget);
  });

  testWidgets('pull to refresh on holdings refreshes, then reloads holdings', (
    tester,
  ) async {
    await tester.pumpWidget(app(PortfolioSection.holdings));
    await tester.pumpAndSettle();
    await tester.fling(find.text('INFY'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(controller.refreshes, 1);
    expect(controller.holdingLoads, 2);
  });

  testWidgets('holdings summary totals and live funds match their rows', (
    tester,
  ) async {
    await tester.pumpWidget(app(PortfolioSection.holdings));
    await tester.pumpAndSettle();

    expect(find.text('Invested'), findsOneWidget);
    expect(find.text('Current value'), findsOneWidget);
    expect(find.text('Day P&L'), findsOneWidget);
    expect(find.text('Total P&L'), findsOneWidget);
    expect(find.text('Funds available · ₹5,000.00'), findsOneWidget);
    expect(find.text('+₹50.00'), findsOneWidget);
    expect(find.text('+₹500.00'), findsOneWidget);
  });

  testWidgets('offline portfolio does not trigger pull-to-refresh', (
    tester,
  ) async {
    await tester.pumpWidget(app(PortfolioSection.orders, offline: true));
    await tester.pumpAndSettle();
    await tester.fling(
      find.text('No orders today'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();
    expect(controller.refreshes, 0);
  });

  testWidgets('MIS and CNC positions stay separate and totals match rows', (
    tester,
  ) async {
    controller.positions = const [
      Position(
        symbol: 'RELIANCE',
        product: ProductType.mis,
        quantity: 130,
        averagePrice: 100,
        realizedPnl: 650,
      ),
      Position(
        symbol: 'RELIANCE',
        quantity: 65,
        averagePrice: 100,
        realizedPnl: 350,
      ),
    ];
    await tester.pumpWidget(app(PortfolioSection.positions));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('RELIANCE|mis')), findsOneWidget);
    expect(find.byKey(const ValueKey('RELIANCE|cnc')), findsOneWidget);
    expect(find.text('+₹1,950.00'), findsOneWidget);
    expect(find.text('+₹1,000.00'), findsOneWidget);
  });

  testWidgets('Refresh status on a pending order asks the controller', (
    tester,
  ) async {
    final pending = Order(
      id: 'pending:k1',
      clientKey: 'k1',
      symbol: 'TCS',
      side: OrderSide.buy,
      type: OrderType.market,
      quantity: 2,
      status: OrderStatus.pending,
      createdAt: DateTime.utc(2026, 11, 8, 4),
      updatedAt: DateTime.utc(2026, 11, 8, 4),
    );
    controller.orders = [pending];
    await tester.pumpWidget(app(PortfolioSection.orders));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refresh status'));
    await tester.pump();

    expect(controller.statusChecks, [pending]);
  });

  testWidgets('a new initial section from the route switches the section', (
    tester,
  ) async {
    await tester.pumpWidget(app(PortfolioSection.orders));
    await tester.pumpAndSettle();
    expect(find.text('No orders today'), findsOneWidget);
    await tester.pumpWidget(app(PortfolioSection.holdings));
    await tester.pumpAndSettle();
    expect(controller.holdingLoads, 1);
    expect(find.text('INFY'), findsOneWidget);
  });
}
