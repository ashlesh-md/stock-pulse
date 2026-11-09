import 'package:flutter_test/flutter_test.dart';
import 'package:option_math/option_math.dart';
import 'package:stock_pulse/features/strategy/application/payoff_geometry.dart';

void main() {
  test('geometry includes exact strike kink, zero and both curves', () {
    final leg = PayoffLeg(
      right: OptionRight.ce,
      strike: 100,
      side: LegSide.buy,
      units: 10,
      premium: 5,
      iv: .2,
      expiryAt: DateTime.utc(2026, 12),
    );
    final geometry = PayoffGeometry.build(
      [leg],
      spot: 100,
      marketNow: DateTime.utc(2026, 11),
    );
    final i = geometry.x.indexOf(100);
    expect(i, greaterThanOrEqualTo(0));
    expect(geometry.expiry[i], -50);
    expect(geometry.today, hasLength(geometry.x.length));
    expect(geometry.yMin, lessThan(0));
    expect(geometry.yMax, greaterThan(0));
    expect(PayoffGeometry.build([leg]).today, isNull);
  });
}
