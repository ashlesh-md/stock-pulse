import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_controller.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_state.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/position_detail_sheet.dart';

class _Portfolio extends PortfolioController {
  _Portfolio(this.ltp);
  final double? ltp;
  @override
  Future<PortfolioState> build() async =>
      PortfolioState(orders: const [], positions: const [], ltp: {'TCS': ?ltp});
}

void main() {
  late OrderTicketArgs? opened;

  Future<void> open(
    WidgetTester tester,
    Position position, {
    double? ltp = 3100,
  }) async {
    opened = null;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => showPositionDetails(context, position: position),
              child: const Text('details'),
            ),
          ),
        ),
        GoRoute(
          path: OrderTicketRoute.path,
          builder: (_, state) {
            opened = OrderTicketRoute.fromState(state).args;
            return const Text('ticket');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          portfolioControllerProvider.overrideWith(() => _Portfolio(ltp)),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.tap(find.text('details'));
    await tester.pumpAndSettle();
  }

  for (final quantity in [12, -7]) {
    testWidgets('CR-2 #11: exit opens the ticket on the closing side for '
        '$quantity shares', (tester) async {
      await open(
        tester,
        Position(
          symbol: 'TCS',
          quantity: quantity,
          averagePrice: 3000,
          realizedPnl: 25,
        ),
      );
      expect(find.text('Average price'), findsOneWidget);
      expect(find.text('₹3,000.00'), findsOneWidget);
      expect(find.text('₹3,100.00'), findsOneWidget);
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      expect(find.text('ticket'), findsOneWidget);
      expect(opened!.side, quantity > 0 ? OrderSide.sell : OrderSide.buy);
      expect(opened!.lots, quantity.abs());
      expect(opened!.source, OrderSource.position);
    });
  }

  testWidgets('CR-2 #11: buy more opens a one-unit buy ticket', (tester) async {
    await open(
      tester,
      const Position(
        symbol: 'TCS',
        quantity: 10,
        averagePrice: 3000,
        realizedPnl: 0,
      ),
    );
    expect(find.text('+1,000.00 (+3.33%)'), findsOneWidget);
    await tester.tap(find.text('Buy more'));
    await tester.pumpAndSettle();
    expect(opened!.side, OrderSide.buy);
    expect(opened!.lots, isNull);
  });

  testWidgets('Exit uses the server lot count and preserves MIS', (
    tester,
  ) async {
    await open(
      tester,
      const Position(
        symbol: 'TCS',
        quantity: 130,
        lots: 2,
        product: ProductType.mis,
        averagePrice: 3000,
        realizedPnl: 0,
      ),
    );
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    expect(opened?.side, OrderSide.sell);
    expect(opened?.lots, 2);
    expect(opened?.product, ProductType.mis);
    expect(opened?.source, OrderSource.position);
  });

  testWidgets('a closed position cannot exit; no price shows a dash', (
    tester,
  ) async {
    await open(
      tester,
      const Position(
        symbol: 'TCS',
        quantity: 0,
        averagePrice: 3000,
        realizedPnl: 40,
      ),
      ltp: null,
    );
    final exit = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Exit'),
    );
    expect(exit.onPressed, isNull);
    expect(find.text('—'), findsNWidgets(3));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(opened, isNull);
  });
}
