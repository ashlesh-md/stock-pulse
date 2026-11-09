import 'dart:math' as math;

/// Call (CE) or put (PE).
enum OptionRight { ce, pe }

/// Black-Scholes sensitivities for one unit of an option.
class Greeks {
  const Greeks({
    required this.delta,
    required this.gamma,
    required this.theta,
    required this.vega,
  });

  /// Per 1 ₹ of spot.
  final double delta;

  /// Per 1 ₹ of spot.
  final double gamma;

  /// ₹ per unit per calendar day (negative for long options).
  final double theta;

  /// ₹ per unit per 1 vol point (0.01).
  final double vega;

  static const zero = Greeks(delta: 0, gamma: 0, theta: 0, vega: 0);

  Greeks copyWith({
    double? delta,
    double? gamma,
    double? theta,
    double? vega,
  }) => Greeks(
    delta: delta ?? this.delta,
    gamma: gamma ?? this.gamma,
    theta: theta ?? this.theta,
    vega: vega ?? this.vega,
  );

  @override
  bool operator ==(Object other) =>
      other is Greeks &&
      other.delta == delta &&
      other.gamma == gamma &&
      other.theta == theta &&
      other.vega == vega;

  @override
  int get hashCode => Object.hash(delta, gamma, theta, vega);

  @override
  String toString() =>
      'Greeks(delta: $delta, gamma: $gamma, theta: $theta, vega: $vega)';
}

const double _msPerYear = 365 * 86400000;
const double _daysPerYear = 365;
final double _invSqrt2Pi = 1 / math.sqrt(2 * math.pi);

/// Black-Scholes price (no dividend). Falls back to intrinsic value when
/// [years] or [iv] is not positive.
double bsPrice({
  required OptionRight right,
  required double spot,
  required double strike,
  required double years,
  required double iv,
  double rate = 0.065,
}) {
  if (years <= 0 || iv <= 0) return _intrinsic(right, spot, strike);
  final sqrtT = math.sqrt(years);
  final d1 =
      (math.log(spot / strike) + (rate + iv * iv / 2) * years) / (iv * sqrtT);
  final d2 = d1 - iv * sqrtT;
  final discK = strike * math.exp(-rate * years);
  return switch (right) {
    OptionRight.ce => spot * normCdf(d1) - discK * normCdf(d2),
    OptionRight.pe => discK * normCdf(-d2) - spot * normCdf(-d1),
  };
}

/// Black-Scholes greeks with the same arguments as [bsPrice].
/// When [years] or [iv] is not positive, delta is 0 or ±1 by moneyness and
/// the other greeks are 0.
Greeks greeks({
  required OptionRight right,
  required double spot,
  required double strike,
  required double years,
  required double iv,
  double rate = 0.065,
}) {
  if (years <= 0 || iv <= 0) {
    final delta = switch (right) {
      OptionRight.ce => spot > strike ? 1.0 : 0.0,
      OptionRight.pe => spot < strike ? -1.0 : 0.0,
    };
    return Greeks.zero.copyWith(delta: delta);
  }
  final sqrtT = math.sqrt(years);
  final d1 =
      (math.log(spot / strike) + (rate + iv * iv / 2) * years) / (iv * sqrtT);
  final d2 = d1 - iv * sqrtT;
  final pdf = normPdf(d1);
  final discK = strike * math.exp(-rate * years);
  final decay = -spot * pdf * iv / (2 * sqrtT);
  return Greeks(
    delta: switch (right) {
      OptionRight.ce => normCdf(d1),
      OptionRight.pe => normCdf(d1) - 1,
    },
    gamma: pdf / (spot * iv * sqrtT),
    theta:
        switch (right) {
          OptionRight.ce => decay - rate * discK * normCdf(d2),
          OptionRight.pe => decay + rate * discK * normCdf(-d2),
        } /
        _daysPerYear,
    vega: spot * pdf * sqrtT / 100,
  );
}

/// Calendar years from [marketNow] to [expiryAt], clamped at 0. Both
/// arguments are market time; no clock is read here.
double yearsToExpiry(DateTime marketNow, DateTime expiryAt) {
  final ms = expiryAt.difference(marketNow).inMilliseconds;
  return ms <= 0 ? 0 : ms / _msPerYear;
}

/// Standard normal CDF, Abramowitz–Stegun 26.2.17 (|error| < 7.5e-8).
double normCdf(double x) {
  const p = 0.2316419;
  const b1 = 0.319381530;
  const b2 = -0.356563782;
  const b3 = 1.781477937;
  const b4 = -1.821255978;
  const b5 = 1.330274429;
  final ax = x.abs();
  final t = 1 / (1 + p * ax);
  final poly = t * (b1 + t * (b2 + t * (b3 + t * (b4 + t * b5))));
  final upper = normPdf(ax) * poly;
  return x >= 0 ? 1 - upper : upper;
}

/// Standard normal PDF.
double normPdf(double x) => _invSqrt2Pi * math.exp(-x * x / 2);

double _intrinsic(OptionRight right, double spot, double strike) =>
    switch (right) {
      OptionRight.ce => math.max(spot - strike, 0),
      OptionRight.pe => math.max(strike - spot, 0),
    };
