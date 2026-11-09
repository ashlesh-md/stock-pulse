import 'dart:math' as math;

import 'package:option_math/src/pricing.dart';

/// Buy or sell. The package has its own enum so it never imports the app's
/// `OrderSide`.
enum LegSide { buy, sell }

/// One leg priced for the payoff maths. [units] = lots × lot size.
final class PayoffLeg {
  const PayoffLeg({
    required this.right,
    required this.strike,
    required this.side,
    required this.units,
    required this.premium,
    required this.iv,
    required this.expiryAt,
  });

  final OptionRight right;
  final double strike;
  final LegSide side;
  final int units;

  /// Entry premium per unit.
  final double premium;

  /// Implied volatility as a fraction (0.14 = 14%), used by [valueToday].
  final double iv;
  final DateTime expiryAt;

  /// +1 for buy, −1 for sell.
  int get sign => side == LegSide.buy ? 1 : -1;

  PayoffLeg copyWith({
    OptionRight? right,
    double? strike,
    LegSide? side,
    int? units,
    double? premium,
    double? iv,
    DateTime? expiryAt,
  }) => PayoffLeg(
    right: right ?? this.right,
    strike: strike ?? this.strike,
    side: side ?? this.side,
    units: units ?? this.units,
    premium: premium ?? this.premium,
    iv: iv ?? this.iv,
    expiryAt: expiryAt ?? this.expiryAt,
  );

  @override
  bool operator ==(Object other) =>
      other is PayoffLeg &&
      other.right == right &&
      other.strike == strike &&
      other.side == side &&
      other.units == units &&
      other.premium == premium &&
      other.iv == iv &&
      other.expiryAt == expiryAt;

  @override
  int get hashCode =>
      Object.hash(right, strike, side, units, premium, iv, expiryAt);
}

/// Exact expiry summary. `null` max profit / max loss means unlimited.
/// [maxLoss] is a P&L value (≤ 0); the UI shows its absolute value.
/// [netPremium] < 0 is a debit.
final class PayoffSummary {
  const PayoffSummary({
    required this.maxProfit,
    required this.maxLoss,
    required this.breakevens,
    required this.netPremium,
    required this.rightSlope,
  });

  factory PayoffSummary.fromJson(Map<String, Object?> json) => PayoffSummary(
    maxProfit: (json['maxProfit'] as num?)?.toDouble(),
    maxLoss: (json['maxLoss'] as num?)?.toDouble(),
    breakevens: [
      for (final b in json['breakevens']! as List) (b as num).toDouble(),
    ],
    netPremium: (json['netPremium']! as num).toDouble(),
    rightSlope: (json['rightSlope']! as num).toDouble(),
  );

  final double? maxProfit;
  final double? maxLoss;
  final List<double> breakevens;
  final double netPremium;

  /// Slope of the payoff for S above the highest strike (Σ s·units over CE).
  final double rightSlope;

  Map<String, Object?> toJson() => {
    'maxProfit': maxProfit,
    'maxLoss': maxLoss,
    'breakevens': breakevens,
    'netPremium': netPremium,
    'rightSlope': rightSlope,
  };

  @override
  bool operator ==(Object other) =>
      other is PayoffSummary &&
      other.maxProfit == maxProfit &&
      other.maxLoss == maxLoss &&
      other.netPremium == netPremium &&
      other.rightSlope == rightSlope &&
      _listEquals(other.breakevens, breakevens);

  @override
  int get hashCode => Object.hash(
    maxProfit,
    maxLoss,
    netPremium,
    rightSlope,
    Object.hashAll(breakevens),
  );

  @override
  String toString() =>
      'PayoffSummary(maxProfit: $maxProfit, maxLoss: $maxLoss, '
      'breakevens: $breakevens, netPremium: $netPremium)';
}

bool _listEquals(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Payoff values this close to zero count as zero (float noise from
/// premiums like 0.05 × units).
const double _zeroEps = 1e-6;

/// Max legs a preview can hold.
const int maxPayoffLegs = 4;

/// P&L at expiry for underlying price [spot]:
/// Σ s·units·(intrinsic − premium).
double payoffAtExpiry(List<PayoffLeg> legs, double spot) {
  var total = 0.0;
  for (final l in legs) {
    total +=
        l.sign * l.units * (_intrinsic(l.right, spot, l.strike) - l.premium);
  }
  return total;
}

/// Exact summary from the kinks (0 and every strike). The payoff is
/// piecewise linear between kinks, so nothing is sampled. Throws
/// [ArgumentError] on 0 or more than [maxPayoffLegs] legs.
PayoffSummary payoffSummary(List<PayoffLeg> legs) {
  if (legs.isEmpty || legs.length > maxPayoffLegs) {
    throw ArgumentError.value(
      legs.length,
      'legs',
      'must have 1 to $maxPayoffLegs legs',
    );
  }
  final xs = <double>{0, for (final l in legs) l.strike}.toList()..sort();
  final vs = [for (final x in xs) _snap(payoffAtExpiry(legs, x))];
  var rightSlope = 0.0;
  for (final l in legs) {
    if (l.right == OptionRight.ce) rightSlope += l.sign * l.units;
  }

  final maxV = vs.reduce(math.max);
  final minV = vs.reduce(math.min);
  final maxProfit = rightSlope > 0 ? null : _round2(maxV);
  final maxLoss = rightSlope < 0 ? null : _round2(math.min(minV, 0));

  final last = xs.length - 1;
  final bes = <double>{};
  for (var i = 0; i < last; i++) {
    final a = vs[i], b = vs[i + 1];
    if (a * b < 0) {
      bes.add(_round2(xs[i] + (0 - a) * (xs[i + 1] - xs[i]) / (b - a)));
    } else if (a == 0 && b == 0) {
      bes
        ..add(_round2(xs[i]))
        ..add(_round2(xs[i + 1]));
    }
  }
  // A kink exactly at zero counts once, and only where the sign changes.
  for (var i = 1; i <= last; i++) {
    if (vs[i] != 0) continue;
    final left = vs[i - 1].sign;
    final right = i < last ? vs[i + 1].sign : rightSlope.sign;
    if (left != 0 && right != 0 && left != right) bes.add(_round2(xs[i]));
  }
  final vLast = vs[last];
  if (vLast != 0 && rightSlope != 0 && vLast.sign != rightSlope.sign) {
    bes.add(_round2(xs[last] - vLast / rightSlope));
  }

  var net = 0.0;
  for (final l in legs) {
    net -= l.sign * l.units * l.premium;
  }
  return PayoffSummary(
    maxProfit: maxProfit,
    maxLoss: maxLoss,
    breakevens: List.unmodifiable(bes.toList()..sort()),
    netPremium: _round2(net),
    rightSlope: rightSlope,
  );
}

/// Mark-to-model P&L now at [spot], using **market time** (TR-18).
/// Equals [payoffAtExpiry] once expired ([bsPrice] falls back to intrinsic).
double valueToday(List<PayoffLeg> legs, double spot, DateTime marketNow) {
  var total = 0.0;
  for (final l in legs) {
    final price = bsPrice(
      right: l.right,
      spot: spot,
      strike: l.strike,
      years: yearsToExpiry(marketNow, l.expiryAt),
      iv: l.iv,
    );
    total += l.sign * l.units * (price - l.premium);
  }
  return total;
}

double _intrinsic(OptionRight right, double spot, double strike) =>
    switch (right) {
      OptionRight.ce => math.max(spot - strike, 0),
      OptionRight.pe => math.max(strike - spot, 0),
    };

double _snap(double v) => v.abs() < _zeroEps ? 0 : v;

double _round2(double v) {
  final r = (v * 100).roundToDouble() / 100;
  return r == 0 ? 0 : r; // no −0.0
}
