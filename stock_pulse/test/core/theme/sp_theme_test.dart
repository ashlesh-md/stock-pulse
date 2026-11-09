import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_typography.dart';

double _luminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('SpColors', () {
    test('dark and light use the 03b v1.4 hex values', () {
      expect(SpColors.dark.surface0, const Color(0xFF0E1116));
      expect(SpColors.dark.up, const Color(0xFF3DDC97));
      expect(SpColors.dark.down, const Color(0xFFFF7A6B));
      expect(SpColors.dark.onSell, const Color(0xFF1A0A08));
      expect(SpColors.light.surface0, const Color(0xFFFFFFFF));
      expect(SpColors.light.up, const Color(0xFF00704F));
      expect(SpColors.light.down, const Color(0xFFC42B1C));
      expect(SpColors.light.onSell, const Color(0xFFFFFFFF));
      // buy = accent, sell = down in both themes.
      for (final c in [SpColors.dark, SpColors.light]) {
        expect(c.buy, c.accent);
        expect(c.sell, c.down);
      }
    });

    test('tints are the token at 14 % alpha', () {
      const c = SpColors.dark;
      expect(c.upTint, c.up.withValues(alpha: 0.14));
      expect(c.downTint, c.down.withValues(alpha: 0.14));
      expect(c.warnTint, c.warn.withValues(alpha: 0.14));
      expect(c.infoTint, c.info.withValues(alpha: 0.14));
    });

    test('directionOf: up, down, zero is textSecondary', () {
      const c = SpColors.dark;
      expect(c.directionOf(0.05), c.up);
      expect(c.directionOf(-3), c.down);
      expect(c.directionOf(0), c.textSecondary);
    });

    test('copyWith replaces only the given fields', () {
      final c = SpColors.dark.copyWith(up: const Color(0xFF000001));
      expect(c.up, const Color(0xFF000001));
      expect(c.down, SpColors.dark.down);
      expect(c.surface0, SpColors.dark.surface0);
      expect(SpColors.dark.copyWith(), SpColors.dark);
    });

    test('lerp: ends, midpoint, and a non-SpColors other returns this', () {
      const a = SpColors.dark, b = SpColors.light;
      expect(a.lerp(b, 0), a);
      expect(a.lerp(b, 1), b);
      final mid = a.lerp(b, 0.5);
      expect(mid.surface0, Color.lerp(a.surface0, b.surface0, 0.5));
      expect(mid.onSell, Color.lerp(a.onSell, b.onSell, 0.5));
      expect(a.lerp(null, 0.5), same(a));
    });

    test('== and hashCode are value based', () {
      expect(SpColors.dark.copyWith(), SpColors.dark);
      expect(SpColors.dark.copyWith().hashCode, SpColors.dark.hashCode);
      expect(SpColors.dark == SpColors.light, isFalse);
    });

    test('every text token passes AA on surface0 and surface1 (NFR-12)', () {
      for (final c in [SpColors.dark, SpColors.light]) {
        final text = {
          'textPrimary': c.textPrimary,
          'textSecondary': c.textSecondary,
          'accent': c.accent,
          'up': c.up,
          'down': c.down,
          'warn': c.warn,
          'info': c.info,
        };
        for (final bg in [c.surface0, c.surface1]) {
          text.forEach((name, fg) {
            expect(
              _contrast(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason: '$name on $bg',
            );
          });
        }
        // Tertiary is hints only, still AA on surface1 per 03b.
        expect(
          _contrast(c.textTertiary, c.surface1),
          greaterThanOrEqualTo(4.5),
        );
        expect(_contrast(c.onAccent, c.accent), greaterThanOrEqualTo(4.5));
        expect(_contrast(c.onSell, c.sell), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('SpTypography', () {
    test('every style has tabular figures and the 03b sizes', () {
      const t = SpTypography.standard;
      for (final s in [t.price, t.priceDense, t.change, t.strike, t.caption]) {
        expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
        expect(s.fontFamily, isNull, reason: 'platform default font');
      }
      expect(t.price.fontSize, 16);
      expect(t.priceDense.fontSize, 14);
      expect(t.change.fontSize, 12);
      expect(t.caption.fontSize, 11);
    });

    test('copyWith and lerp', () {
      const t = SpTypography.standard;
      const big = TextStyle(fontSize: 40);
      expect(t.copyWith(price: big).price, big);
      expect(t.copyWith(price: big).caption, t.caption);
      expect(t.lerp(null, 0.5), same(t));
      final other = t.copyWith(price: t.price.copyWith(fontSize: 20));
      expect(t.lerp(other, 0.5).price.fontSize, 18);
    });
  });

  group('AppTheme + SpThemeX', () {
    testWidgets('context.sp and context.spText resolve per brightness', (
      tester,
    ) async {
      late SpColors dark, light;
      late SpTypography text;
      Widget probe(ThemeData theme, void Function(BuildContext) read) =>
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                read(context);
                return const SizedBox();
              },
            ),
          );

      await tester.pumpWidget(
        probe(AppTheme.dark(), (c) {
          dark = c.sp;
          text = c.spText;
        }),
      );
      // New tree, so MaterialApp does not animate between the two themes.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(probe(AppTheme.light(), (c) => light = c.sp));

      expect(dark, SpColors.dark);
      expect(light, SpColors.light);
      expect(text, SpTypography.standard);
    });

    test('ColorScheme maps to the tokens, no seed', () {
      for (final (theme, c) in [
        (AppTheme.dark(), SpColors.dark),
        (AppTheme.light(), SpColors.light),
      ]) {
        final s = theme.colorScheme;
        expect(s.surface, c.surface0);
        expect(s.primary, c.accent);
        expect(s.onPrimary, c.onAccent);
        expect(s.error, c.down);
        expect(s.onSurface, c.textPrimary);
        expect(s.onSurfaceVariant, c.textSecondary);
        expect(s.outlineVariant, c.outline);
        expect(s.surfaceContainerLow, c.surface1);
        expect(s.surfaceContainerHigh, c.surface2);
        expect(theme.scaffoldBackgroundColor, c.surface0);
        expect(theme.navigationBarTheme.height, 80);
        expect(
          theme.navigationBarTheme.iconTheme!.resolve({
            WidgetState.selected,
          })!.color,
          c.onAccent,
        );
        expect(
          theme.navigationBarTheme.labelTextStyle!.resolve({
            WidgetState.selected,
          })!.color,
          c.textPrimary,
        );
        expect(theme.navigationRailTheme.selectedIconTheme!.color, c.onAccent);
        expect(
          theme.navigationRailTheme.selectedLabelTextStyle!.color,
          c.textPrimary,
        );
        expect(_contrast(c.textPrimary, c.surface1), greaterThanOrEqualTo(4.5));
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
        expect(theme.bottomSheetTheme.showDragHandle, isTrue);
      }
      expect(AppTheme.dark().brightness, Brightness.dark);
      expect(AppTheme.light().brightness, Brightness.light);
    });
  });
}
