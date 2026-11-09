import 'package:option_math/src/payoff.dart';
import 'package:option_math/src/pricing.dart';
import 'package:test/test.dart';

final _expiry = DateTime.utc(2026, 11, 10, 10);

PayoffLeg _leg(
  OptionRight right,
  double strike,
  LegSide side,
  double premium, {
  int units = 50,
  double iv = 0.14,
}) => PayoffLeg(
  right: right,
  strike: strike,
  side: side,
  units: units,
  premium: premium,
  iv: iv,
  expiryAt: _expiry,
);

const _ce = OptionRight.ce;
const _pe = OptionRight.pe;
const _buy = LegSide.buy;
const _sell = LegSide.sell;

void main() {
  group('types', () {
    test('PayoffLeg is equal by value', () {
      final a = _leg(_ce, 24500, _buy, 120);
      expect(a, _leg(_ce, 24500, _buy, 120));
      expect(a.hashCode, _leg(_ce, 24500, _buy, 120).hashCode);
      expect(a, isNot(_leg(_ce, 24500, _sell, 120)));
    });

    test('PayoffSummary hashes by value and prints its risk numbers', () {
      const a = PayoffSummary(
        maxProfit: null,
        maxLoss: -100,
        breakevens: [24620],
        netPremium: -100,
        rightSlope: 50,
      );
      const b = PayoffSummary(
        maxProfit: null,
        maxLoss: -100,
        breakevens: [24620],
        netPremium: -100,
        rightSlope: 50,
      );
      expect(a.hashCode, b.hashCode);
      expect(
        a.toString(),
        'PayoffSummary(maxProfit: null, maxLoss: -100.0, '
        'breakevens: [24620.0], netPremium: -100.0)',
      );
    });

    test('PayoffSummary has value equality and a JSON round trip', () {
      const s = PayoffSummary(
        maxProfit: null,
        maxLoss: -6250,
        breakevens: [24625],
        netPremium: -6250,
        rightSlope: 50,
      );
      expect(PayoffSummary.fromJson(s.toJson()), s);
      expect(s.toJson()['maxProfit'], isNull);
      expect(
        s,
        isNot(
          const PayoffSummary(
            maxProfit: null,
            maxLoss: -6250,
            breakevens: [24626],
            netPremium: -6250,
            rightSlope: 50,
          ),
        ),
      );
    });

    test('PayoffLeg has value equality and a sign', () {
      final buy = _leg(_ce, 24500, _buy, 125);
      expect(buy, buy.copyWith());
      expect(buy.sign, 1);
      expect(buy.copyWith(side: _sell).sign, -1);
      expect(buy.copyWith(units: 75), isNot(buy));
    });
  });

  group('payoffAtExpiry', () {
    test('sums sign × units × (intrinsic − premium)', () {
      final legs = [_leg(_ce, 24500, _buy, 125), _leg(_pe, 24500, _sell, 100)];
      // S = 24700: CE 200 − 125 = 75; short PE: −(0 − 100) = 100.
      expect(payoffAtExpiry(legs, 24700), (75 + 100) * 50);
      // S = 24300: CE −125; short PE: −(200 − 100) = −100.
      expect(payoffAtExpiry(legs, 24300), (-125 - 100) * 50);
    });
  });

  group('payoffSummary', () {
    test('P1 long CE: max loss = −premium × units, profit unlimited', () {
      final s = payoffSummary([_leg(_ce, 24500, _buy, 125)]);
      expect(s.maxLoss, -6250);
      expect(s.maxProfit, isNull);
      expect(s.breakevens, [24625]);
      expect(s.netPremium, -6250);
      expect(s.rightSlope, 50);
    });

    test('P2 short CE: loss unlimited, profit = premium × units', () {
      final s = payoffSummary([_leg(_ce, 24500, _sell, 125)]);
      expect(s.maxLoss, isNull);
      expect(s.maxProfit, 6250);
      expect(s.breakevens, [24625]);
      expect(s.netPremium, 6250);
      expect(s.rightSlope, -50);
    });

    test('P2 long PE: max profit = (K − premium) × units at S = 0', () {
      final s = payoffSummary([_leg(_pe, 24500, _buy, 100)]);
      expect(s.maxProfit, (24500 - 100) * 50);
      expect(s.maxLoss, -5000);
      expect(s.breakevens, [24400]);
      expect(s.rightSlope, 0);
    });

    test('P3 long straddle: V shape with BEs at K ± total premium', () {
      final s = payoffSummary([
        _leg(_ce, 24500, _buy, 125),
        _leg(_pe, 24500, _buy, 119),
      ]);
      expect(s.breakevens, [24256, 24744]);
      expect(s.netPremium, -(125 + 119) * 50);
      expect(s.maxLoss, -(125 + 119) * 50);
      expect(s.maxProfit, isNull);
    });

    test('P4 bull call spread: bounded both ways, one exact BE', () {
      final s = payoffSummary([
        _leg(_ce, 24500, _buy, 125),
        _leg(_ce, 24600, _sell, 75),
      ]);
      expect(s.maxLoss, -2500);
      expect(s.maxProfit, (100 - 50) * 50);
      expect(s.breakevens, [24550]);
      expect(s.rightSlope, 0);
    });

    test('P4 iron condor: 4 legs bounded, both BEs exact', () {
      final s = payoffSummary([
        _leg(_pe, 24200, _sell, 50),
        _leg(_pe, 24000, _buy, 20),
        _leg(_ce, 24600, _sell, 45),
        _leg(_ce, 24800, _buy, 15),
      ]);
      expect(s.netPremium, 60 * 50);
      expect(s.maxProfit, 60 * 50);
      expect(s.maxLoss, -(200 - 60) * 50);
      expect(s.breakevens, [24140, 24660]);
    });

    test('P4 BE exactly at a kink is reported once', () {
      // −5 flat to 100, −5 → 0 at 105, then slope 2 upward.
      final s = payoffSummary([
        _leg(_ce, 100, _buy, 5, units: 1),
        _leg(_ce, 105, _buy, 0, units: 1),
      ]);
      expect(s.breakevens, [105]);
    });

    test('P4 zero-flat segment reports both ends, no duplicates', () {
      // Positive at S = 0, 0 on [90, 110], positive above.
      final s = payoffSummary([
        _leg(_pe, 90, _buy, 0, units: 1),
        _leg(_ce, 110, _buy, 0, units: 1),
      ]);
      expect(s.breakevens, [90, 110]);
      expect(s.maxLoss, 0);
    });

    test('breakevens are rounded to 2 dp and sorted', () {
      final s = payoffSummary([_leg(_ce, 24500, _buy, 125.333)]);
      expect(s.breakevens, [24625.33]);
    });

    test('P6 0 or 5 legs throw ArgumentError', () {
      expect(() => payoffSummary(const []), throwsArgumentError);
      final five = List.generate(
        5,
        (i) => _leg(_ce, 24000.0 + i * 100, _buy, 10),
      );
      expect(() => payoffSummary(five), throwsArgumentError);
    });
  });

  group('valueToday', () {
    final legs = [_leg(_ce, 24500, _buy, 125), _leg(_pe, 24400, _sell, 90)];

    test('P5 at or after expiry equals payoffAtExpiry', () {
      for (final spot in [24000.0, 24450.0, 24900.0]) {
        expect(valueToday(legs, spot, _expiry), payoffAtExpiry(legs, spot));
        expect(
          valueToday(legs, spot, _expiry.add(const Duration(days: 1))),
          payoffAtExpiry(legs, spot),
        );
      }
    });

    test('P5 before expiry equals Σ bsPrice − premium on market time', () {
      final marketNow = DateTime.utc(2026, 11, 5, 4);
      final years = yearsToExpiry(marketNow, _expiry);
      final ce = bsPrice(
        right: _ce,
        spot: 24480,
        strike: 24500,
        years: years,
        iv: 0.14,
      );
      final pe = bsPrice(
        right: _pe,
        spot: 24480,
        strike: 24400,
        years: years,
        iv: 0.14,
      );
      final expected = 50 * (ce - 125) - 50 * (pe - 90);
      expect(valueToday(legs, 24480, marketNow), closeTo(expected, 1e-9));
      // A different market time gives a different value: no wall clock read.
      expect(
        valueToday(legs, 24480, marketNow.subtract(const Duration(days: 2))),
        isNot(closeTo(expected, 1e-6)),
      );
    });
  });
}
