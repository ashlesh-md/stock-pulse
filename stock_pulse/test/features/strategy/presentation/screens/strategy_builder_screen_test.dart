import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/strategy/application/strategy_builder_controller.dart';
import 'package:stock_pulse/features/strategy/application/strategy_builder_state.dart';
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';
import 'package:stock_pulse/features/strategy/presentation/screens/strategy_builder_screen.dart';

const _leg = StrategyLeg(
  contractId: 'NIFTY-261110-24500-CE',
  side: OrderSide.buy,
  lots: 1,
  premium: 120,
);

class _Builder extends StrategyBuilderController {
  @override
  Future<StrategyBuilderState> build() async => StrategyBuilderState(
    instruments: const [],
    legs: const [],
    summary: null,
    geometry: null,
  );
}

void main() {
  testWidgets('shows the shown leg count and follows draft changes', (
    tester,
  ) async {
    final container = ProviderContainer.test(
      overrides: [strategyBuilderControllerProvider.overrideWith(_Builder.new)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const StrategyBuilderScreen(),
        ),
      ),
    );
    expect(find.text('Legs (0/4)'), findsOneWidget);
    final draft = container.read(strategyDraftControllerProvider.notifier)
      ..addLeg('NIFTY-261110-24500-CE', OrderSide.buy, 100);
    await tester.pump();
    expect(find.text('Legs (1/4)'), findsOneWidget);
    draft.load(const StrategyArgs(legs: [_leg, _leg]));
    await tester.pump();
    expect(find.text('Legs (2/4)'), findsOneWidget);
  });

  testWidgets('Open option chain goes to the chain tab', (tester) async {
    final router = GoRouter(
      initialLocation: StrategyRoute.path,
      routes: [
        GoRoute(
          path: StrategyRoute.path,
          builder: (_, _) => const StrategyBuilderScreen(),
        ),
        GoRoute(
          path: OptionChainRoute.path,
          builder: (_, _) => const Text('chain tab'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          strategyBuilderControllerProvider.overrideWith(_Builder.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open option chain'));
    await tester.pumpAndSettle();
    expect(find.text('chain tab'), findsOneWidget);
  });
}
