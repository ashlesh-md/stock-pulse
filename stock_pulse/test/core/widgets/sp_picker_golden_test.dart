import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/widgets/sp_picker.dart';

void main() {
  for (final (themeName, theme) in [
    ('dark', AppTheme.dark()),
    ('light', AppTheme.light()),
  ]) {
    for (final ratio in [1.0, 2.0]) {
      testWidgets('S-59 picker sheet $themeName at ${ratio}x', (tester) async {
        tester.view.devicePixelRatio = ratio;
        tester.view.physicalSize = Size(390 * ratio, 844 * ratio);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
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
          ),
        );
        await tester.tap(find.text('5 minutes').first);
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/sp_picker_${themeName}_${ratio.toInt()}x.png',
          ),
        );
      });
    }
  }
}
