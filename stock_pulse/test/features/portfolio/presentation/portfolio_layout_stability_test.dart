import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/widgets/empty_view.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_controller.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_funds_provider.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_state.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';
import 'package:stock_pulse/features/portfolio/domain/holding.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_section.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';
import 'package:stock_pulse/features/portfolio/presentation/screens/portfolio_screen.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/pnl_card.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/position_tile.dart';

const _infy = Holding(symbol: 'INFY', quantity: 5, averagePrice: 1500);

class _Portfolio extends PortfolioController {
  _Portfolio({this.initial = const PortfolioState(orders: [], positions: [])});

  final PortfolioState initial;

  @override
  Future<PortfolioState> build() async => initial;

  @override
  Future<void> loadHoldings() async {
    state = AsyncData(state.requireValue.copyWith(loadingHoldings: true));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    state = AsyncData(
      state.requireValue.copyWith(
        loadingHoldings: false,
        holdingsLoaded: true,
        holdings: const [_infy],
      ),
    );
  }
}

class _Empty extends _Portfolio {
  int loads = 0;

  @override
  Future<void> loadHoldings() async {
    loads++;
    state = AsyncData(state.requireValue.copyWith(loadingHoldings: true));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    state = AsyncData(
      state.requireValue.copyWith(loadingHoldings: false, holdingsLoaded: true),
    );
  }
}

void main() {
  Widget app(_Portfolio controller, PortfolioSection section) => ProviderScope(
    retry: (_, _) => null,
    overrides: [
      portfolioControllerProvider.overrideWith(() => controller),
      portfolioFundsProvider.overrideWith(
        (ref) => Stream.value(const Funds(available: 5000, version: 1)),
      ),
      networkStatusProvider.overrideWith((ref) => const Stream.empty()),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: PortfolioScreen(initialSection: section),
    ),
  );

  testWidgets('switching sections swaps rows in place without a slide', (
    tester,
  ) async {
    await tester.pumpWidget(app(_Portfolio(), PortfolioSection.positions));
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.byType(PnlCard));

    await tester.tap(find.text('Orders'));
    await tester.pump();

    expect(find.byType(PnlCard), findsOneWidget);
    expect(tester.getTopLeft(find.byType(PnlCard)), before);
  });

  testWidgets('holdings show a spinner, never the empty state, before the '
      'first load finishes', (tester) async {
    await tester.pumpWidget(app(_Portfolio(), PortfolioSection.holdings));
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 5));
      expect(find.byType(EmptyView), findsNothing);
    }
    await tester.pumpAndSettle();
    expect(find.text('INFY'), findsOneWidget);
  });

  testWidgets('reloading holdings keeps the rows still and shows no spinner', (
    tester,
  ) async {
    final controller = _Portfolio(
      initial: const PortfolioState(
        orders: [],
        positions: [],
        holdings: [_infy],
        holdingsLoaded: true,
        ltp: {'INFY': 1600},
      ),
    );
    await tester.pumpWidget(app(controller, PortfolioSection.holdings));
    await tester.pumpAndSettle();
    final row = tester.getTopLeft(find.text('INFY'));

    await tester.tap(find.text('Positions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Holdings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.getTopLeft(find.text('INFY')), row);
    await tester.pumpAndSettle();
  });

  testWidgets('a position row keeps its size when its price arrives', (
    tester,
  ) async {
    const position = Position(
      symbol: 'INFY',
      quantity: 5,
      averagePrice: 1500,
      realizedPnl: 0,
    );
    final controller = _Portfolio(
      initial: const PortfolioState(orders: [], positions: [position]),
    );
    await tester.pumpWidget(app(controller, PortfolioSection.positions));
    await tester.pumpAndSettle();
    final waiting = tester.getSize(find.byType(PositionTile));

    controller.state = AsyncData(
      controller.state.requireValue.copyWith(ltp: const {'INFY': 1612.35}),
    );
    await tester.pump();

    expect(find.textContaining('1,612.35'), findsOneWidget);
    expect(tester.getSize(find.byType(PositionTile)), waiting);
  });

  testWidgets('reloading empty holdings keeps the empty state on screen', (
    tester,
  ) async {
    final controller = _Empty();
    await tester.pumpWidget(app(controller, PortfolioSection.holdings));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyView), findsOneWidget);

    await tester.tap(find.text('Positions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Holdings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(controller.loads, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(EmptyView), findsOneWidget);
    await tester.pumpAndSettle();
  });

  test('holdingsLoaded takes part in copyWith and equality', () {
    const empty = PortfolioState(orders: [], positions: []);
    final loaded = empty.copyWith(holdingsLoaded: true);
    expect(loaded.holdingsLoaded, isTrue);
    expect(loaded, isNot(empty));
    expect(loaded.hashCode, isNot(empty.hashCode));
    expect(loaded.copyWith(), loaded);
  });
}
