import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/widgets/sp_picker.dart';

Widget _picker(ThemeData theme) => MaterialApp(
  theme: theme,
  home: Scaffold(
    body: Center(
      child: SpPicker<String>(
        title: 'Interval',
        values: const [
          '1 minute',
          '5 minutes',
          '15 minutes',
          '1 hour',
          '1 day',
        ],
        label: (value) => value,
        selected: '5 minutes',
        onChanged: (_) {},
      ),
    ),
  ),
);

void main() {
  for (final (name, theme) in [
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    testWidgets('S-59 AC2 ($name): sheet rows pass tap-target and contrast, '
        'the selected row has a tick and selected semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_picker(theme));
      await tester.tap(find.text('5 minutes'));
      await tester.pumpAndSettle();

      expect(find.byIcon(AppIcons.success), findsOneWidget);
      expect(
        tester.getSemantics(
          find.ancestor(
            of: find.text('5 minutes').last,
            matching: find.byType(ListTile),
          ),
        ),
        isSemantics(isSelected: true),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}
