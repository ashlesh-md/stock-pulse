import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:option_math/option_math.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/strategy/application/payoff_geometry.dart';
import 'package:stock_pulse/features/strategy/presentation/widgets/payoff_chart.dart';

List<PayoffLeg> _legs({required bool straddle}) => [
  PayoffLeg(
    right: OptionRight.ce,
    strike: 25000,
    side: LegSide.buy,
    units: 65,
    premium: 120,
    iv: 0,
    expiryAt: DateTime.utc(2026, 11, 26),
  ),
  if (straddle)
    PayoffLeg(
      right: OptionRight.pe,
      strike: 25000,
      side: LegSide.buy,
      units: 65,
      premium: 120,
      iv: 0,
      expiryAt: DateTime.utc(2026, 11, 26),
    ),
];

void main() {
  final themes = [('dark', AppTheme.dark()), ('light', AppTheme.light())];
  for (final (themeName, theme) in themes) {
    for (final straddle in [false, true]) {
      final shape = straddle ? 'straddle' : 'single_leg';
      testWidgets('$shape payoff chart has a $themeName theme golden', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final legs = _legs(straddle: straddle);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 358,
                  child: PayoffChart(
                    geometry: PayoffGeometry.build(legs, spot: 25000),
                    summary:
                        'Max loss ${Fmt.price(payoffSummary(legs).maxLoss!.abs())}',
                  ),
                ),
              ),
            ),
          ),
        );
        await expectLater(
          find.byType(PayoffChart),
          matchesGoldenFile('goldens/payoff_${shape}_$themeName.png'),
        );
      });
    }
  }
}
