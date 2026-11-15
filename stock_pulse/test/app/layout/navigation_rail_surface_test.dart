import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/layout/navigation_rail_surface.dart';

void main() {
  testWidgets('rail surface falls back to the theme surface color', (
    tester,
  ) async {
    final theme = ThemeData.dark().copyWith(
      navigationRailTheme: const NavigationRailThemeData(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: const NavigationRailSurface(child: SizedBox.expand()),
      ),
    );

    expect(
      tester
          .widget<ColoredBox>(
            find.byKey(const ValueKey('navigation-rail-surface')),
          )
          .color,
      theme.colorScheme.surface,
    );
  });
}
