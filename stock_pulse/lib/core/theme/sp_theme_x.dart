import 'package:flutter/material.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/core/theme/sp_typography.dart';

/// `context.sp.up`, `context.spText.price`. Both extensions are always
/// registered by `AppTheme`, so a missing one is a wiring bug.
extension SpThemeX on BuildContext {
  SpColors get sp => Theme.of(this).extension<SpColors>()!;
  SpTypography get spText => Theme.of(this).extension<SpTypography>()!;
}
