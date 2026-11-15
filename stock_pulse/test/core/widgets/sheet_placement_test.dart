import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/widgets/sheet_placement_scope.dart';

void main() {
  testWidgets('side-sheet placement survives replacing its content', (
    tester,
  ) async {
    Widget child(String value) => MaterialApp(
      home: SheetPlacementScope(
        child: Builder(
          builder: (context) =>
              Text('${SheetPlacementScope.usesSideSheet(context)}:$value'),
        ),
      ),
    );
    await tester.pumpWidget(child('first'));
    expect(find.text('true:first'), findsOneWidget);
    await tester.pumpWidget(child('second'));
    expect(find.text('true:second'), findsOneWidget);
  });
}
