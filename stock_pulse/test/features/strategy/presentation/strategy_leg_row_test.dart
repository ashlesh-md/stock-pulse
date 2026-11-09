import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';
import 'package:stock_pulse/features/strategy/presentation/widgets/strategy_leg_row.dart';

void main() {
  testWidgets('leg row updates side and lot count, trades and removes', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                final leg = ref
                    .watch(strategyDraftControllerProvider)
                    .shownLegs
                    .firstOrNull;
                return leg == null
                    ? const Text('No legs')
                    : StrategyLegRow(leg: leg, index: 0);
              },
            ),
          ),
        ),
        GoRoute(
          path: '/order/:id',
          builder: (_, state) => Text('Order ${state.pathParameters['id']}'),
        ),
      ],
    );
    final container = ProviderContainer.test();
    container
        .read(strategyDraftControllerProvider.notifier)
        .load(
          const StrategyArgs(
            legs: [
              StrategyLeg(
                contractId: 'NIFTY-261126-25000-CE',
                side: OrderSide.buy,
                lots: 1,
                premium: 120,
              ),
            ],
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );

    await tester.tap(find.text('SELL'));
    await tester.pump();
    expect(
      tester
          .widget<SegmentedButton<OrderSide>>(
            find.byType(SegmentedButton<OrderSide>),
          )
          .selected,
      {OrderSide.sell},
    );
    await tester.tap(find.bySemanticsLabel('Increase lots'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Trade'));
    await tester.pumpAndSettle();
    expect(find.text('Order NIFTY-261126-25000-CE'), findsOneWidget);
    expect(router.state.uri.queryParameters['side'], 'sell');
    expect(router.state.uri.queryParameters['lots'], '2');

    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove leg'));
    await tester.pump();
    expect(find.text('No legs'), findsOneWidget);
    router.dispose();
  });
}
