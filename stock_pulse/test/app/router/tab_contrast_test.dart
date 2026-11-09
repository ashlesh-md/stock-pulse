import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  const selected = {WidgetState.selected};
  const idle = <WidgetState>{};

  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    group('$name theme: the selected tab meets WCAG AA', () {
      test('bottom bar', () {
        final bar = theme.navigationBarTheme;
        final background = bar.backgroundColor!;
        final indicator = bar.indicatorColor!;
        final icon = bar.iconTheme!.resolve(selected)!.color!;
        final idleIcon = bar.iconTheme!.resolve(idle)!.color!;
        final label = bar.labelTextStyle!.resolve(selected)!;
        final idleLabel = bar.labelTextStyle!.resolve(idle)!;

        expect(contrast(icon, indicator), greaterThanOrEqualTo(4.5));
        expect(contrast(indicator, background), greaterThanOrEqualTo(3));
        expect(contrast(idleIcon, background), greaterThanOrEqualTo(3));
        expect(contrast(label.color!, background), greaterThanOrEqualTo(4.5));
        expect(
          contrast(idleLabel.color!, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(label.fontWeight, FontWeight.w700);
        expect(idleLabel.fontWeight, isNot(FontWeight.w700));
      });

      test('rail', () {
        final rail = theme.navigationRailTheme;
        final background = rail.backgroundColor!;
        final indicator = rail.indicatorColor!;
        expect(
          contrast(rail.selectedIconTheme!.color!, indicator),
          greaterThanOrEqualTo(4.5),
        );
        expect(contrast(indicator, background), greaterThanOrEqualTo(3));
        expect(
          contrast(rail.unselectedIconTheme!.color!, background),
          greaterThanOrEqualTo(3),
        );
        expect(
          contrast(rail.selectedLabelTextStyle!.color!, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(rail.unselectedLabelTextStyle!.color!, background),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }
}
