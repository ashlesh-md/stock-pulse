import 'package:flutter/material.dart';

/// Numeric text styles. Every style has tabular figures baked
/// in, so columns of prices never jitter. Colour is left unset: widgets apply
/// a token from `context.sp`. Font is the platform default.
@immutable
class SpTypography extends ThemeExtension<SpTypography> {
  const SpTypography({
    required this.price,
    required this.priceDense,
    required this.change,
    required this.strike,
    required this.caption,
  });

  /// Watchlist and positions LTP: 16 / 22 / w600.
  final TextStyle price;

  /// Chain LTP, table cells: 14 / 18 / w500.
  final TextStyle priceDense;

  /// Change and %, OI change: 12 / 16 / w500.
  final TextStyle change;

  /// Chain strike column: 14 / 18 / w600.
  final TextStyle strike;

  /// Timestamps, "as of": 11 / 14 / w500. Never for key numbers.
  final TextStyle caption;

  static const _tabular = [FontFeature.tabularFigures()];

  static const standard = SpTypography(
    price: TextStyle(
      fontSize: 16,
      height: 22 / 16,
      fontWeight: FontWeight.w600,
      fontFeatures: _tabular,
    ),
    priceDense: TextStyle(
      fontSize: 14,
      height: 18 / 14,
      fontWeight: FontWeight.w500,
      fontFeatures: _tabular,
    ),
    change: TextStyle(
      fontSize: 12,
      height: 16 / 12,
      fontWeight: FontWeight.w500,
      fontFeatures: _tabular,
    ),
    strike: TextStyle(
      fontSize: 14,
      height: 18 / 14,
      fontWeight: FontWeight.w600,
      fontFeatures: _tabular,
    ),
    caption: TextStyle(
      fontSize: 11,
      height: 14 / 11,
      fontWeight: FontWeight.w500,
      fontFeatures: _tabular,
    ),
  );

  @override
  SpTypography copyWith({
    TextStyle? price,
    TextStyle? priceDense,
    TextStyle? change,
    TextStyle? strike,
    TextStyle? caption,
  }) {
    return SpTypography(
      price: price ?? this.price,
      priceDense: priceDense ?? this.priceDense,
      change: change ?? this.change,
      strike: strike ?? this.strike,
      caption: caption ?? this.caption,
    );
  }

  @override
  SpTypography lerp(ThemeExtension<SpTypography>? other, double t) {
    if (other is! SpTypography) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return SpTypography(
      price: l(price, other.price),
      priceDense: l(priceDense, other.priceDense),
      change: l(change, other.change),
      strike: l(strike, other.strike),
      caption: l(caption, other.caption),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpTypography &&
          other.price == price &&
          other.priceDense == priceDense &&
          other.change == change &&
          other.strike == strike &&
          other.caption == caption;

  @override
  int get hashCode => Object.hash(price, priceDense, change, strike, caption);
}
