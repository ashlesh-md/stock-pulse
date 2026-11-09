import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/theme/sp_typography.dart';
import 'package:stock_pulse/core/widgets/change_chip.dart';
import 'package:stock_pulse/core/widgets/market_status_pill.dart';

import '../../helpers/sp_app.dart';

void main() {
  testWidgets('ChangeChip without data shows a dash, not a colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(const ChangeChip(change: null, changePct: null)),
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.bySemanticsLabel('Change unavailable'), findsOneWidget);
  });

  testWidgets('MarketStatusPill: Closed, and stacked at large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: spApp(
          MarketStatusPill(key: UniqueKey()),
          overrides: [
            marketClockProvider.overrideWith(
              (ref) => Stream.value(
                MarketClockState.fallback.copyWith(
                  phase: MarketPhase.closed,
                  overridden: true,
                ),
              ),
            ),
            clockProvider.overrideWithValue(
              FakeClock(DateTime.utc(2026, 11, 9, 12)),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Closed'), findsOneWidget);
    expect(find.byType(Column), findsWidgets);
  });

  test('Fmt dates: day-time, date, day-month, month-year', () {
    final t = DateTime.utc(2026, 1, 5, 4, 30);
    expect(Fmt.dayTime(t), contains('5 Jan'));
    expect(Fmt.date(t), contains('2026'));
    expect(Fmt.dayMonth(t), '5 Jan');
    expect(Fmt.monthYear(t), 'Jan 26');
  });

  test('SpTypography is value-equal', () {
    const t = SpTypography.standard;
    expect(t, t.copyWith());
    expect(t.hashCode, t.copyWith().hashCode);
    expect(t == t.copyWith(price: const TextStyle(fontSize: 1)), isFalse);
  });
}
