import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/core/widgets/sp_price_cell.dart';

import '../../helpers/sp_app.dart';

// Replaces v1 tick_price_test.dart (TickPrice is deleted, LLD §3 step 5).
void main() {
  final t0 = DateTime.utc(2026, 11, 9, 5);
  late FakeClock clock;

  setUp(() => clock = FakeClock(t0));

  Future<Color?> show(
    WidgetTester tester, {
    DateTime? lastTickAt,
    TickDirection dir = TickDirection.none,
    bool stale = false,
    double? value = 101,
  }) async {
    await tester.pumpWidget(
      spApp(
        SpPriceCell(
          value: value,
          text: '101.00',
          lastTickAt: lastTickAt,
          lastDirection: dir,
          isStale: stale,
        ),
        overrides: [clockProvider.overrideWithValue(clock)],
      ),
    );
    return tester.widget<Text>(find.byType(Text)).style?.color;
  }

  testWidgets('no tick yet → textPrimary', (tester) async {
    expect(await show(tester), SpColors.dark.textPrimary);
  });

  testWidgets('up/down colour only within 1.5 s of the last tick', (
    tester,
  ) async {
    clock.set(t0.add(const Duration(milliseconds: 1499)));
    expect(
      await show(tester, lastTickAt: t0, dir: TickDirection.up),
      SpColors.dark.up,
    );
    expect(
      await show(tester, lastTickAt: t0, dir: TickDirection.down),
      SpColors.dark.down,
    );
    clock.set(t0.add(const Duration(milliseconds: 1500)));
    expect(
      await show(tester, lastTickAt: t0, dir: TickDirection.up),
      SpColors.dark.textPrimary,
      reason: 'reset to primary 1.5 s after the change, computed at build',
    );
    expect(tester.hasRunningAnimations, isFalse, reason: 'no flash animation');
  });

  testWidgets('stale → textTertiary even right after a tick', (tester) async {
    expect(
      await show(tester, lastTickAt: t0, dir: TickDirection.up, stale: true),
      SpColors.dark.textTertiary,
    );
  });

  testWidgets('null value shows a dash; semantics name the direction', (
    tester,
  ) async {
    await show(tester, value: null);
    expect(find.text('—'), findsOneWidget);
    await show(tester, lastTickAt: t0, dir: TickDirection.up);
    expect(find.bySemanticsLabel('Price 101.00 rupees, up'), findsOneWidget);
  });
}
