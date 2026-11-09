import 'dart:math' as math;

import 'package:option_math/option_math.dart';

class PayoffGeometry {
  PayoffGeometry({
    required this.x,
    required this.expiry,
    required this.today,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.spot,
  });
  factory PayoffGeometry.build(
    List<PayoffLeg> legs, {
    double? spot,
    DateTime? marketNow,
  }) {
    final strikes = legs.map((l) => l.strike).toList();
    final low = [...strikes, ?spot].reduce(math.min);
    final high = [...strikes, ?spot].reduce(math.max);
    final width = math.max((high - low).abs(), high * .12);
    final xMin = math.max(0.0, low - width * .5);
    final xMax = high + width * .5;
    final x = <double>{
      xMin,
      xMax,
      ...strikes.where((s) => s >= xMin && s <= xMax),
      for (var i = 0; i <= 120; i++) xMin + (xMax - xMin) * i / 120,
    }.toList()..sort();
    final expiry = [for (final value in x) payoffAtExpiry(legs, value)];
    final today = marketNow == null
        ? null
        : [for (final value in x) valueToday(legs, value, marketNow)];
    final values = [0.0, ...expiry, ...?today];
    final min = values.reduce(math.min), max = values.reduce(math.max);
    final padding = math.max(1.0, (max - min) * .1);
    return PayoffGeometry(
      x: List.unmodifiable(x),
      expiry: List.unmodifiable(expiry),
      today: today == null ? null : List.unmodifiable(today),
      xMin: xMin,
      xMax: xMax,
      yMin: min - padding,
      yMax: max + padding,
      spot: spot,
    );
  }
  final List<double> x;
  final List<double> expiry;
  final List<double>? today;
  final double xMin, xMax, yMin, yMax;
  final double? spot;
}
