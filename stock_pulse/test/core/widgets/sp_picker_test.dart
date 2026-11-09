import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/widgets/sp_multi_picker.dart';
import 'package:stock_pulse/core/widgets/sp_picker.dart';

void main() {
  testWidgets('multi-picker commits changes only when Done is tapped', (
    tester,
  ) async {
    Set<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpMultiPicker<String>(
            title: 'Columns',
            values: const ['OI', 'ΔOI', 'LTP', 'IV'],
            label: (value) => value,
            selected: const {'OI', 'LTP'},
            disabledValues: const ['LTP'],
            onChanged: (values) => result = values,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Columns'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(4));
    expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(500));
    expect(
      tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .firstWhere((tile) => (tile.title as Text).data == 'LTP')
          .enabled,
      isFalse,
    );
    await tester.tap(find.text('IV'));
    await tester.pump();
    expect(result, isNull);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, {'OI', 'LTP', 'IV'});
  });

  testWidgets('short choices use a segmented control and return one value', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpPicker<String>(
            title: 'Range',
            values: const ['1D', '1W', '1M'],
            label: (value) => value,
            selected: '1D',
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );

    expect(find.byType(SegmentedButton<String>), findsOneWidget);
    await tester.tap(find.text('1M'));
    expect(selected, '1M');
  });

  testWidgets('large text and long option labels use the picker sheet', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: SpPicker<String>(
                title: 'Instrument',
                values: const ['Tata Consultancy Services', 'Reliance'],
                label: (value) => value,
                selected: 'Tata Consultancy Services',
                onChanged: (value) => selected = value,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SegmentedButton<String>), findsNothing);
    await tester.tap(find.text('Tata Consultancy Services').first);
    await tester.pumpAndSettle();
    final selectedTile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Tata Consultancy Services').last,
        matching: find.byType(ListTile),
      ),
    );
    expect(selectedTile.selected, isTrue);
    expect(
      tester.getSize(find.byType(ListTile).first).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Reliance').last);
    await tester.pumpAndSettle();
    expect(selected, 'Reliance');
  });

  testWidgets('disabled options do nothing and loading is explicit', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                SpPicker<String>(
                  title: 'Instrument',
                  values: const ['A', 'B', 'C', 'D', 'E'],
                  label: (value) => value,
                  selected: 'A',
                  disabledValues: const ['B'],
                  onChanged: (value) => selected = value,
                ),
                const SpPicker<String>(
                  title: 'Loading values',
                  values: [],
                  label: _identity,
                  selected: null,
                  loading: true,
                  onChanged: _ignore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Loading...'), findsOneWidget);
    await tester.tap(find.text('A').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('B').last, findsOneWidget);
    final disabled = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .firstWhere((tile) => (tile.title as Text).data == 'B');
    expect(disabled.enabled, isFalse);
    await tester.tap(find.text('B').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(selected, isNull);
  });

  testWidgets('picker searches and returns the chosen value', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showSpPicker<String>(
                  context,
                  title: 'Instrument',
                  values: const [
                    'NIFTY',
                    'RELIANCE',
                    'TCS',
                    'INFOSYS',
                    'SBIN',
                    'ICICIBANK',
                  ],
                  label: (s) => s,
                );
              },
              child: const Text('Choose'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rel');
    await tester.pumpAndSettle();
    expect(find.text('NIFTY'), findsNothing);
    await tester.tap(find.text('RELIANCE'));
    await tester.pumpAndSettle();
    expect(selected, 'RELIANCE');
  });

  testWidgets('short option lists use a compact sheet without search', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showSpPicker<String>(
                context,
                title: 'Order type',
                values: const ['Market', 'Limit', 'Stop loss'],
                label: (value) => value,
              ),
              child: const Text('Choose'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(tester.getSize(find.byType(BottomSheet)).height, lessThan(360));
  });
}

String _identity(String value) => value;
void _ignore(String value) {}
