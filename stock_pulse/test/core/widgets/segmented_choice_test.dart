import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/widgets/segmented_choice.dart';

import '../../helpers/sp_app.dart';

void main() {
  late List<String> picks;
  setUp(() => picks = []);

  Widget choice({bool enabled = true, String market = 'Market'}) => spApp(
    SegmentedChoice<String>(
      segments: [
        SpSegment('mkt', market),
        const SpSegment('lmt', 'Limit'),
        const SpSegment('sl', 'Stop', enabled: false),
      ],
      selected: 'mkt',
      onChanged: enabled ? picks.add : null,
    ),
  );

  FontWeight? weightOf(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style?.fontWeight;

  testWidgets('tapping another segment reports it', (tester) async {
    await tester.pumpWidget(choice());

    await tester.tap(find.text('Limit'));

    expect(picks, ['lmt']);
  });

  testWidgets('tapping the selected or a disabled segment does nothing', (
    tester,
  ) async {
    await tester.pumpWidget(choice());

    await tester.tap(find.text('Market'));
    await tester.tap(find.text('Stop'), warnIfMissed: false);

    expect(picks, isEmpty);
  });

  testWidgets('the selected segment is bold, the others are not', (
    tester,
  ) async {
    await tester.pumpWidget(choice());

    expect(weightOf(tester, 'Market'), FontWeight.w700);
    expect(weightOf(tester, 'Limit'), FontWeight.w500);
  });

  testWidgets('a null onChanged disables the whole control', (tester) async {
    await tester.pumpWidget(choice(enabled: false));

    final button = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(button.onSelectionChanged, isNull);
    await tester.tap(find.text('Limit'), warnIfMissed: false);
    expect(picks, isEmpty);
  });
}
