import 'package:flutter/material.dart';

/// Colour tokens from the design system. The only place in the
/// app that may name a colour value; widgets read `context.sp`.
@immutable
class SpColors extends ThemeExtension<SpColors> {
  const SpColors({
    required this.surface0,
    required this.surface1,
    required this.surface2,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.up,
    required this.down,
    required this.warn,
    required this.info,
    required this.buy,
    required this.sell,
    required this.onSell,
  });

  final Color surface0;
  final Color surface1;
  final Color surface2;
  final Color outline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color onAccent;
  final Color up;
  final Color down;
  final Color warn;
  final Color info;
  final Color buy;
  final Color sell;
  final Color onSell;

  static const _tintAlpha = 0.14;
  static const transparent = Color(0x00000000);

  /// Chip and bar backgrounds only, never behind small text.
  Color get upTint => up.withValues(alpha: _tintAlpha);
  Color get downTint => down.withValues(alpha: _tintAlpha);
  Color get warnTint => warn.withValues(alpha: _tintAlpha);
  Color get infoTint => info.withValues(alpha: _tintAlpha);

  Color get shadow => const Color(0x8A000000);

  /// Up / down colour for a change value; zero is `textSecondary`.
  Color directionOf(num change) => change > 0
      ? up
      : change < 0
      ? down
      : textSecondary;

  static const dark = SpColors(
    surface0: Color(0xFF0E1116),
    surface1: Color(0xFF171C24),
    surface2: Color(0xFF202733),
    outline: Color(0xFF2C3544),
    textPrimary: Color(0xFFE8ECF2),
    textSecondary: Color(0xFFA3ADBB),
    textTertiary: Color(0xFF7F8A99),
    accent: Color(0xFF5AA9FF),
    onAccent: Color(0xFF06121F),
    up: Color(0xFF3DDC97),
    down: Color(0xFFFF7A6B),
    warn: Color(0xFFF2B84B),
    info: Color(0xFF6CB4FF),
    buy: Color(0xFF5AA9FF),
    sell: Color(0xFFFF7A6B),
    onSell: Color(0xFF1A0A08),
  );

  static const light = SpColors(
    surface0: Color(0xFFFFFFFF),
    surface1: Color(0xFFF3F5F8),
    surface2: Color(0xFFE8ECF2),
    outline: Color(0xFFD5DBE4),
    textPrimary: Color(0xFF12161C),
    textSecondary: Color(0xFF4A5565),
    textTertiary: Color(0xFF667085),
    accent: Color(0xFF0B5CAD),
    onAccent: Color(0xFFFFFFFF),
    up: Color(0xFF00704F),
    down: Color(0xFFC42B1C),
    warn: Color(0xFF8A5A00),
    info: Color(0xFF0B5CAD),
    buy: Color(0xFF0B5CAD),
    sell: Color(0xFFC42B1C),
    onSell: Color(0xFFFFFFFF),
  );

  @override
  SpColors copyWith({
    Color? surface0,
    Color? surface1,
    Color? surface2,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? onAccent,
    Color? up,
    Color? down,
    Color? warn,
    Color? info,
    Color? buy,
    Color? sell,
    Color? onSell,
  }) {
    return SpColors(
      surface0: surface0 ?? this.surface0,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      up: up ?? this.up,
      down: down ?? this.down,
      warn: warn ?? this.warn,
      info: info ?? this.info,
      buy: buy ?? this.buy,
      sell: sell ?? this.sell,
      onSell: onSell ?? this.onSell,
    );
  }

  @override
  SpColors lerp(ThemeExtension<SpColors>? other, double t) {
    if (other is! SpColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SpColors(
      surface0: l(surface0, other.surface0),
      surface1: l(surface1, other.surface1),
      surface2: l(surface2, other.surface2),
      outline: l(outline, other.outline),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      up: l(up, other.up),
      down: l(down, other.down),
      warn: l(warn, other.warn),
      info: l(info, other.info),
      buy: l(buy, other.buy),
      sell: l(sell, other.sell),
      onSell: l(onSell, other.onSell),
    );
  }

  List<Color> get _fields => [
    surface0,
    surface1,
    surface2,
    outline,
    textPrimary,
    textSecondary,
    textTertiary,
    accent,
    onAccent,
    up,
    down,
    warn,
    info,
    buy,
    sell,
    onSell,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SpColors) return false;
    final a = _fields, b = other._fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);
}
