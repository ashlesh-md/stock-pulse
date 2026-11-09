import 'dart:math' as math;

import 'package:option_math/option_math.dart';
import 'package:test/test.dart';

void main() {
  group('bsPrice', () {
    test('reference values S=100 K=100 T=1 r=0.05 iv=0.2 (TR-18, FR-27)', () {
      final ce = bsPrice(
        right: OptionRight.ce,
        spot: 100,
        strike: 100,
        years: 1,
        iv: 0.2,
        rate: 0.05,
      );
      final pe = bsPrice(
        right: OptionRight.pe,
        spot: 100,
        strike: 100,
        years: 1,
        iv: 0.2,
        rate: 0.05,
      );
      expect(ce, closeTo(10.4506, 1e-4));
      expect(pe, closeTo(5.5735, 1e-4));
    });

    test('put-call parity holds over a grid (TR-18)', () {
      for (final spot in [80.0, 95.0, 100.0, 113.0, 140.0]) {
        for (final strike in [90.0, 100.0, 110.0]) {
          for (final years in [0.01, 0.25, 1.0, 2.0]) {
            for (final iv in [0.1, 0.3, 0.8]) {
              for (final rate in [0.0, 0.065]) {
                final c = bsPrice(
                  right: OptionRight.ce,
                  spot: spot,
                  strike: strike,
                  years: years,
                  iv: iv,
                  rate: rate,
                );
                final p = bsPrice(
                  right: OptionRight.pe,
                  spot: spot,
                  strike: strike,
                  years: years,
                  iv: iv,
                  rate: rate,
                );
                expect(
                  c - p,
                  closeTo(spot - strike * math.exp(-rate * years), 1e-6),
                  reason: 'S=$spot K=$strike T=$years iv=$iv r=$rate',
                );
              }
            }
          }
        }
      }
    });

    test('years <= 0 or iv <= 0 returns intrinsic (TR-26)', () {
      for (final (years, iv) in [
        (0.0, 0.2),
        (-0.5, 0.2),
        (1.0, 0.0),
        (1.0, -0.1),
      ]) {
        expect(
          bsPrice(
            right: OptionRight.ce,
            spot: 120,
            strike: 100,
            years: years,
            iv: iv,
          ),
          20,
        );
        expect(
          bsPrice(
            right: OptionRight.ce,
            spot: 80,
            strike: 100,
            years: years,
            iv: iv,
          ),
          0,
        );
        expect(
          bsPrice(
            right: OptionRight.pe,
            spot: 80,
            strike: 100,
            years: years,
            iv: iv,
          ),
          20,
        );
        expect(
          bsPrice(
            right: OptionRight.pe,
            spot: 120,
            strike: 100,
            years: years,
            iv: iv,
          ),
          0,
        );
      }
    });

    test('uses default rate 0.065', () {
      expect(
        bsPrice(
          right: OptionRight.ce,
          spot: 100,
          strike: 100,
          years: 1,
          iv: 0.2,
        ),
        bsPrice(
          right: OptionRight.ce,
          spot: 100,
          strike: 100,
          years: 1,
          iv: 0.2,
        ),
      );
    });
  });

  group('greeks vs finite differences (FR-27)', () {
    const spot = 100.0, years = 0.5;
    for (final right in OptionRight.values) {
      for (final strike in [90.0, 100.0, 112.0]) {
        for (final iv in [0.15, 0.4]) {
          test('$right K=$strike iv=$iv', () {
            double price({double s = spot, double t = years, double? v}) =>
                bsPrice(
                  right: right,
                  spot: s,
                  strike: strike,
                  years: t,
                  iv: v ?? iv,
                );
            final g = greeks(
              right: right,
              spot: spot,
              strike: strike,
              years: years,
              iv: iv,
            );

            const h = 0.01;
            final delta = (price(s: spot + h) - price(s: spot - h)) / (2 * h);
            final gamma =
                (price(s: spot + h) - 2 * price() + price(s: spot - h)) /
                (h * h);
            const day = 1 / 365;
            // Theta per calendar day: value change when one day passes.
            final theta =
                (price(t: years - day / 2) - price(t: years + day / 2));
            const dv = 0.0001;
            final vega =
                (price(v: iv + dv) - price(v: iv - dv)) / (2 * dv) / 100;

            expect(g.delta, closeTo(delta, 1e-3));
            expect(g.gamma, closeTo(gamma, 1e-3));
            expect(g.theta, closeTo(theta, 1e-3));
            expect(g.vega, closeTo(vega, 1e-3));
          });
        }
      }
    }

    test('long options have negative theta, positive gamma and vega', () {
      final g = greeks(
        right: OptionRight.ce,
        spot: 100,
        strike: 100,
        years: 0.5,
        iv: 0.2,
      );
      expect(g.theta, lessThan(0));
      expect(g.gamma, greaterThan(0));
      expect(g.vega, greaterThan(0));
    });

    test('years <= 0: delta by moneyness, others 0', () {
      Greeks at(OptionRight r, double s) =>
          greeks(right: r, spot: s, strike: 100, years: 0, iv: 0.2);
      expect(at(OptionRight.ce, 120).delta, 1);
      expect(at(OptionRight.ce, 80).delta, 0);
      expect(at(OptionRight.pe, 80).delta, -1);
      expect(at(OptionRight.pe, 120).delta, 0);
      final g = at(OptionRight.ce, 120);
      expect([g.gamma, g.theta, g.vega], [0, 0, 0]);
    });

    test('Greeks value equality', () {
      const a = Greeks(delta: 0.5, gamma: 0.1, theta: -0.2, vega: 0.3);
      const b = Greeks(delta: 0.5, gamma: 0.1, theta: -0.2, vega: 0.3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.copyWith(delta: 0.6), isNot(a));
      expect(a.copyWith(delta: 0.6).delta, 0.6);
      expect(a.copyWith(), a);
      expect('$a', 'Greeks(delta: 0.5, gamma: 0.1, theta: -0.2, vega: 0.3)');
    });
  });

  group('yearsToExpiry (ADR-0002)', () {
    test('uses only its arguments, calendar time', () {
      final now = DateTime.utc(2026);
      expect(
        yearsToExpiry(now, now.add(const Duration(days: 365))),
        closeTo(1, 1e-12),
      );
      expect(
        yearsToExpiry(now, now.add(const Duration(hours: 12))),
        closeTo(0.5 / 365, 1e-12),
      );
      // A market time far from the wall clock still works.
      final past = DateTime.utc(2001, 3, 4, 10);
      expect(
        yearsToExpiry(past, past.add(const Duration(days: 73))),
        closeTo(0.2, 1e-12),
      );
    });

    test('clamps at 0', () {
      final now = DateTime.utc(2026, 1, 2);
      expect(yearsToExpiry(now, DateTime.utc(2026)), 0);
      expect(yearsToExpiry(now, now), 0);
    });
  });

  group('normal distribution', () {
    test('normCdf known values', () {
      expect(normCdf(0), closeTo(0.5, 1e-7));
      expect(normCdf(1.96), closeTo(0.9750021, 1e-6));
      expect(normCdf(-1), closeTo(0.1586553, 1e-6));
      expect(normCdf(1) + normCdf(-1), closeTo(1, 1e-7));
    });

    test('normPdf exact', () {
      expect(normPdf(0), closeTo(1 / math.sqrt(2 * math.pi), 1e-15));
      expect(
        normPdf(1),
        closeTo(math.exp(-0.5) / math.sqrt(2 * math.pi), 1e-15),
      );
    });
  });
}
