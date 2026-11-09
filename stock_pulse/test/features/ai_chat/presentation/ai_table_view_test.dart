import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_table_view.dart';

import '../../../helpers/sp_app.dart';

const _compare = {
  'columns': [
    {'key': 'symbol', 'label': 'Symbol'},
    {'key': 'ltp', 'label': 'LTP', 'format': 'price'},
    {'key': 'changePct', 'label': 'Change %', 'format': 'pct'},
  ],
  'rows': [
    {
      'id': 'BAJFINANCE',
      'cells': {'symbol': 'BAJFINANCE', 'ltp': 13106.25, 'changePct': -0.09},
    },
    {
      'id': 'INFY',
      'cells': {'symbol': 'INFY', 'ltp': 1506.45, 'changePct': 1.2},
    },
    {
      'cells': {'symbol': 'FLAT', 'ltp': 'n/a', 'changePct': 0},
    },
  ],
};

void main() {
  final opened = <String>[];
  setUp(opened.clear);

  Future<void> pumpTable(WidgetTester tester, {double width = 358}) =>
      tester.pumpWidget(
        spApp(
          Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: AiTableView(body: _compare, onOpenRow: opened.add),
              ),
            ),
          ),
        ),
      );

  testWidgets('a compare table has no selection checkboxes', (tester) async {
    await pumpTable(tester);

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(DataTable), findsNothing);
  });

  testWidgets('every column fits inside the card on a phone, so no cell is '
      'clipped', (tester) async {
    await pumpTable(tester, width: 300);

    expect(tester.takeException(), isNull);
    for (final text in ['Change %', '₹13,106.25', '-0.09%', 'BAJFINANCE']) {
      final rect = tester.getRect(find.text(text));
      expect(rect.left, greaterThanOrEqualTo(0), reason: text);
      expect(rect.right, lessThanOrEqualTo(300), reason: text);
    }
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('prices use the rupee formatter and change is signed and '
      'coloured by direction', (tester) async {
    await pumpTable(tester);
    final sp = Theme.of(tester.element(find.byType(AiTableView)))
        .extension<SpColors>()!;
    Color? colorOf(String text) =>
        tester.widget<Text>(find.text(text)).style?.color;

    expect(find.text('₹13,106.25'), findsOneWidget);
    expect(find.text('₹1,506.45'), findsOneWidget);
    expect(colorOf('-0.09%'), sp.down);
    expect(colorOf('+1.20%'), sp.up);
    expect(colorOf('+0.00%'), sp.textSecondary);
    expect(find.text('n/a'), findsOneWidget);
  });

  testWidgets('a row with an id opens it; one without does nothing', (
    tester,
  ) async {
    await pumpTable(tester);

    await tester.tap(find.text('INFY'));
    await tester.tap(find.text('FLAT'));
    expect(opened, ['INFY']);
  });

  testWidgets('a table with no columns draws nothing', (tester) async {
    await tester.pumpWidget(
      spApp(AiTableView(body: const {}, onOpenRow: opened.add)),
    );

    expect(find.byType(Row), findsNothing);
  });
}
