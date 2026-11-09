import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:option_math/option_math.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/strategy/application/payoff_geometry.dart';
import 'package:stock_pulse/features/strategy/application/strategy_builder_controller.dart';
import 'package:stock_pulse/features/strategy/application/strategy_builder_state.dart';
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';
import 'package:stock_pulse/features/strategy/presentation/screens/strategy_builder_screen.dart';
import 'package:stock_pulse/features/strategy/presentation/widgets/payoff_chart.dart';
import 'package:stock_pulse/features/strategy/presentation/widgets/strategy_leg_row.dart';

const _leg = StrategyLeg(
  contractId: 'NIFTY-261126-25000-CE',
  side: OrderSide.buy,
  lots: 1,
  premium: 120,
);

PayoffGeometry _geometry() => PayoffGeometry.build([
  PayoffLeg(
    right: OptionRight.ce,
    strike: 25000,
    side: LegSide.buy,
    units: 25,
    premium: 120,
    iv: 0,
    expiryAt: DateTime.utc(2026, 11, 26),
  ),
]);

StrategyBuilderState _pricedState({
  required bool bounded,
  bool todayLive = false,
}) => StrategyBuilderState(
  instruments: const [],
  legs: const [],
  summary: PayoffSummary(
    maxProfit: bounded ? 1000 : null,
    maxLoss: bounded ? -120 : null,
    breakevens: const [25120],
    netPremium: -120,
    rightSlope: 25,
  ),
  geometry: _geometry(),
  todayLive: todayLive,
);

class _Builder extends StrategyBuilderController {
  _Builder(this.buildValue);
  final Future<StrategyBuilderState> Function() buildValue;
  int retries = 0;

  @override
  Future<StrategyBuilderState> build() => buildValue();

  @override
  void retry() => retries++;
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Builder builder, {
  bool withLeg = false,
}) async {
  final container = ProviderContainer.test(
    overrides: [strategyBuilderControllerProvider.overrideWith(() => builder)],
  );
  if (withLeg) {
    container
        .read(strategyDraftControllerProvider.notifier)
        .load(const StrategyArgs(legs: [_leg]));
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const StrategyBuilderScreen(),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('priced strategy renders unlimited bounds and draft controls', (
    tester,
  ) async {
    await _pump(
      tester,
      _Builder(() async => _pricedState(bounded: false)),
      withLeg: true,
    );

    expect(find.text('Legs (1/4)'), findsOneWidget);
    expect(find.byType(PayoffChart), findsOneWidget);
    expect(find.byType(StrategyLegRow), findsOneWidget);
    expect(find.text('Max profit: Unlimited'), findsOneWidget);
    expect(find.text('Max loss: Unlimited'), findsOneWidget);
    expect(find.text('Today line needs live prices'), findsOneWidget);
    expect(find.text('Breakevens: ₹25,120.00'), findsOneWidget);
  });

  testWidgets('bounded summary formats values and omits unavailable line', (
    tester,
  ) async {
    await _pump(
      tester,
      _Builder(() async => _pricedState(bounded: true, todayLive: true)),
    );

    expect(find.text('Max profit: ₹1,000.00'), findsOneWidget);
    expect(find.text('Max loss: ₹120.00'), findsOneWidget);
    expect(find.text('Net premium: -₹120.00'), findsOneWidget);
    expect(find.text('Today line needs live prices'), findsNothing);
  });

  testWidgets('shows loading and then pricing error with retry', (
    tester,
  ) async {
    final wait = Completer<StrategyBuilderState>();
    final builder = _Builder(() => wait.future);
    await _pump(tester, builder, withLeg: true);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    wait.completeError(StateError('pricing failed'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Could not price legs. Retry'), findsOneWidget);
    await tester.tap(find.text('Could not price legs. Retry'));
    expect(builder.retries, 1);
  });
}
