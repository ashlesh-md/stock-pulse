import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/widgets/stale_badge.dart';
import 'package:stock_pulse/features/chart/presentation/readout_row.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

import '../../../helpers/sp_app.dart';

void main() {
  testWidgets('shows OHLCV, change and stale status for the selected candle', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        ReadoutRow(
          candle: Candle(
            start: DateTime.utc(2026, 11, 9),
            open: 100,
            high: 110,
            low: 95,
            close: 105,
            volume: 1200,
          ),
          previousClose: 100,
          staleSince: DateTime.utc(2026, 11, 9, 5),
        ),
      ),
    );

    final renderedValues = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .toList();
    expect(renderedValues, contains('O ${Fmt.price(100)}'));
    expect(renderedValues, contains('H ${Fmt.price(110)}'));
    expect(renderedValues, contains('L ${Fmt.price(95)}'));
    expect(renderedValues, contains('C ${Fmt.price(105)}'));
    expect(renderedValues, contains('V ${Fmt.compact(1200)}'));
    expect(renderedValues.any((text) => text.contains(Fmt.percent(5))), isTrue);
    expect(find.byType(StaleBadge), findsOneWidget);
  });
}
