import 'package:flutter/material.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/core/theme/sp_typography.dart';

/// Material themes built from the tokens. Explicit
/// `ColorScheme`, no seed colour.
abstract final class AppTheme {
  // Built once: the component themes hold `WidgetStateProperty` closures,
  // so two builds are never equal and `AnimatedTheme` would animate on every
  // rebuild of `MaterialApp`.
  static final ThemeData _dark = _build(Brightness.dark, SpColors.dark);
  static final ThemeData _light = _build(Brightness.light, SpColors.light);

  static ThemeData dark() => _dark;
  static ThemeData light() => _light;

  static ThemeData _build(Brightness brightness, SpColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.onAccent,
      secondary: c.accent,
      onSecondary: c.onAccent,
      error: c.down,
      onError: c.onSell,
      surface: c.surface0,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      outline: c.outline,
      outlineVariant: c.outline,
      surfaceContainerLowest: c.surface0,
      surfaceContainerLow: c.surface1,
      surfaceContainer: c.surface1,
      surfaceContainerHigh: c.surface2,
      surfaceContainerHighest: c.surface2,
    );
    const radiusM = BorderRadius.all(Radius.circular(SpRadius.m));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.surface0,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: c.surface0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        titleSpacing: SpSpace.s4,
      ),
      dividerTheme: DividerThemeData(color: c.outline, thickness: 1, space: 1),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: c.surface2,
          foregroundColor: c.textSecondary,
          selectedBackgroundColor: c.accent,
          selectedForegroundColor: c.onAccent,
          side: BorderSide(color: c.outline),
          minimumSize: const Size(0, SpDensity.tap),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface1,
        showDragHandle: true,
        dragHandleColor: c.textTertiary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(SpRadius.l)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.surface2,
        contentTextStyle: TextStyle(color: c.textPrimary),
        actionTextColor: c.accent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: c.surface1,
        indicatorColor: c.accent,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? c.onAccent
                : c.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                // The label sits outside the selected indicator, so it must
                // contrast with the navigation surface rather than accent.
                ? c.textPrimary
                : c.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface1,
        indicatorColor: c.accent,
        selectedIconTheme: IconThemeData(color: c.onAccent),
        unselectedIconTheme: IconThemeData(color: c.textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: c.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(color: c.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        border: const OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radiusM,
          borderSide: BorderSide(color: c.down),
        ),
      ),
      extensions: [c, SpTypography.standard],
    );
  }
}
