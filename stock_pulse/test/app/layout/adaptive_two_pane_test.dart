import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/layout/adaptive_two_pane.dart';
import 'package:stock_pulse/app/layout/pane_placeholder.dart';
import 'package:stock_pulse/app/layout/window_class.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    Widget? secondary,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: AdaptiveTwoPane(
          primary: const _Counter(),
          secondary: secondary,
          placeholder: const PanePlaceholder(
            icon: Icons.show_chart,
            message: 'Pick one',
          ),
        ),
      ),
    );
  }

  testWidgets('compact and medium show the list alone, capped and centred', (
    tester,
  ) async {
    await pump(tester, width: 1000, secondary: const Text('detail'));
    expect(find.text('detail'), findsNothing);
    expect(find.text('Pick one'), findsNothing);
    final list = find.byType(_Counter);
    expect(tester.getSize(list).width, ContentWidth.list);
    expect(tester.getCenter(list).dx, 500);
  });

  testWidgets('expanded shows the placeholder until something is picked', (
    tester,
  ) async {
    await pump(tester, width: 1400);
    expect(tester.getSize(find.byType(_Counter)).width, ContentWidth.listPane);
    expect(find.text('Pick one'), findsOneWidget);
    expect(find.byType(VerticalDivider), findsOneWidget);
  });

  testWidgets('expanded shows the picked detail beside the list', (
    tester,
  ) async {
    await pump(tester, width: 1400, secondary: const Text('detail'));
    expect(find.text('detail'), findsOneWidget);
    expect(find.text('Pick one'), findsNothing);
    expect(
      tester.getTopLeft(find.text('detail')).dx,
      greaterThan(ContentWidth.listPane),
    );
  });

  testWidgets('the list keeps its state when the window class changes', (
    tester,
  ) async {
    await pump(tester, width: 500);
    await tester.tap(find.text('0'));
    await tester.pump();
    tester.view.physicalSize = const Size(1400, 800);
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Pick one'), findsOneWidget);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => _taps++),
    child: Text('$_taps'),
  );
}
