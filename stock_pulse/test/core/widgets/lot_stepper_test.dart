import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/widgets/lot_stepper.dart';

import '../../helpers/sp_app.dart';

void main() {
  late List<int> changes;
  setUp(() => changes = []);

  Widget stepper({
    int value = 2,
    int min = 1,
    int max = 3,
    bool enabled = true,
    String? unit,
  }) => spApp(
    LotStepper(
      value: value,
      min: min,
      max: max,
      unitLabel: unit,
      onChanged: enabled ? changes.add : null,
    ),
  );

  Finder button(String label) => find.bySemanticsLabel(label);

  testWidgets('plus and minus step by one and report the new value', (
    tester,
  ) async {
    await tester.pumpWidget(stepper());

    await tester.tap(find.byType(IconButton).last);
    await tester.tap(find.byType(IconButton).first);

    expect(changes, [3, 2]);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a step past min or max is ignored and the button disabled', (
    tester,
  ) async {
    await tester.pumpWidget(stepper(value: 1, max: 1));

    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons.every((b) => b.onPressed == null), isTrue);
    await tester.tap(find.byType(IconButton).last, warnIfMissed: false);
    expect(changes, isEmpty);
  });

  testWidgets('a null onChanged disables both buttons', (tester) async {
    await tester.pumpWidget(stepper(enabled: false));

    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons.every((b) => b.onPressed == null), isTrue);
  });

  testWidgets('long-press repeats every 100 ms and stops at max', (
    tester,
  ) async {
    await tester.pumpWidget(stepper(value: 1, max: 4));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(IconButton).last),
    );
    await tester.pump(kLongPressTimeout);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(changes, [2, 3, 4]);
  });

  testWidgets('releasing a long-press stops the repeat', (tester) async {
    await tester.pumpWidget(stepper(value: 1, max: 9));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(IconButton).last),
    );
    await tester.pump(kLongPressTimeout);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));

    expect(changes, [2]);
  });

  testWidgets('a new value from the parent replaces the stepped one', (
    tester,
  ) async {
    await tester.pumpWidget(stepper());
    await tester.tap(find.byType(IconButton).last);
    await tester.pumpWidget(stepper(value: 1));

    await tester.tap(find.byType(IconButton).last);

    expect(changes, [3, 2]);
  });

  testWidgets('speaks lots by default and the given unit otherwise', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(stepper());
    expect(find.bySemanticsLabel('2 lots'), findsOneWidget);
    expect(button('Increase lots'), findsOneWidget);
    expect(button('Decrease lots'), findsOneWidget);

    await tester.pumpWidget(stepper(unit: 'qty'));
    expect(find.bySemanticsLabel('2 qty'), findsOneWidget);
    expect(button('Increase qty'), findsOneWidget);
    semantics.dispose();
  });
}
