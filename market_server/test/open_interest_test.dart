import 'dart:math';

import 'package:market_server/src/open_interest.dart';
import 'package:option_math/option_math.dart';
import 'package:test/test.dart';

void main() {
  OpenInterest listed({Random? random}) => OpenInterest(random: random)
    ..list(
      'ATM-CE',
      lot: 65,
      strike: 24600,
      spot: 24600,
      step: 50,
      right: OptionRight.ce,
    )
    ..list(
      'OTM-CE',
      lot: 65,
      strike: 25000,
      spot: 24600,
      step: 50,
      right: OptionRight.ce,
    )
    ..list(
      'ITM-CE',
      lot: 65,
      strike: 24200,
      spot: 24600,
      step: 50,
      right: OptionRight.ce,
    )
    ..list(
      'OTM-PE',
      lot: 65,
      strike: 24200,
      spot: 24600,
      step: 50,
      right: OptionRight.pe,
    );

  test(
    'B10 seed peaks at the money in whole lots and skews out of the money',
    () {
      final oi = listed();
      expect(oi.oi('ATM-CE'), 65 * 4000);
      expect(oi.oi('OTM-CE') % 65, 0);
      expect(oi.oi('OTM-CE'), lessThan(oi.oi('ATM-CE')));
      expect(oi.oi('ITM-CE'), lessThan(oi.oi('OTM-CE')));
      expect(oi.oi('OTM-PE'), oi.oi('OTM-CE'));
      expect(oi.change('ATM-CE'), 0);
      expect(oi.oi('unknown'), 0);
    },
  );

  test('listing again keeps the drifted value', () {
    final oi = listed(random: Random(1));
    for (var i = 0; i < 200; i++) {
      oi.step();
    }
    final drifted = oi.oi('ATM-CE');
    oi.list(
      'ATM-CE',
      lot: 65,
      strike: 24600,
      spot: 1,
      step: 50,
      right: OptionRight.ce,
    );
    expect(oi.oi('ATM-CE'), drifted);
  });

  test('B10 OI drifts in lots during the day and ΔOI follows it', () {
    final oi = listed(random: Random(7));
    for (var i = 0; i < 200; i++) {
      oi.step();
    }
    final ids = ['ATM-CE', 'OTM-CE', 'ITM-CE', 'OTM-PE'];
    expect(ids.where((id) => oi.change(id) != 0), isNotEmpty);
    for (final id in ids) {
      expect(oi.oi(id), greaterThanOrEqualTo(0));
      expect(oi.change(id) % 65, 0);
    }
  });

  test('OI never goes below zero', () {
    final oi = OpenInterest(random: Random(3))
      ..list(
        'FAR',
        lot: 1,
        strike: 30000,
        spot: 100,
        step: 50,
        right: OptionRight.ce,
      );
    expect(oi.oi('FAR'), 0);
    for (var i = 0; i < 500; i++) {
      oi.step();
      expect(oi.oi('FAR'), greaterThanOrEqualTo(0));
    }
  });

  test('a day roll restarts ΔOI from the current OI', () {
    final oi = listed(random: Random(7));
    for (var i = 0; i < 200; i++) {
      oi.step();
    }
    final before = oi.oi('ATM-CE');
    oi.rollDay();
    expect(oi.change('ATM-CE'), 0);
    expect(oi.oi('ATM-CE'), before);
  });
}
