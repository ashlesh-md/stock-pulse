import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';

const _leg = StrategyLeg(
  contractId: 'NIFTY-261110-24500-CE',
  side: OrderSide.buy,
  lots: 1,
  premium: 120,
);

void main() {
  group('chainKeyOf', () {
    test('drops strike and right from an option id', () {
      expect(chainKeyOf('NIFTY-261110-24500-CE'), 'NIFTY-261110');
    });

    test('keeps a hyphenated underlying whole', () {
      expect(chainKeyOf('BAJAJ-AUTO-261127-9000-PE'), 'BAJAJ-AUTO-261127');
    });

    test('returns an id without strike and right unchanged', () {
      expect(chainKeyOf('RELIANCE'), 'RELIANCE');
    });
  });

  group('StrategyLeg', () {
    test('copyWith changes only the given fields', () {
      final sold = _leg.copyWith(side: OrderSide.sell, lots: 3, premium: 99);
      expect(sold.contractId, _leg.contractId);
      expect(sold.side, OrderSide.sell);
      expect(sold.lots, 3);
      expect(sold.premium, 99);
      expect(_leg.copyWith(), _leg);
    });

    test('is equal by value', () {
      expect(_leg.copyWith(lots: 2), isNot(_leg));
      expect(_leg.copyWith(lots: 2).copyWith(lots: 1), _leg);
      expect(_leg.copyWith().hashCode, _leg.hashCode);
    });

    test('toString names the contract, side, lots and premium', () {
      expect(
        _leg.toString(),
        'StrategyLeg(NIFTY-261110-24500-CE, buy, 1 lot(s), 120.0)',
      );
    });
  });

  test('StrategyArgs is equal by legs', () {
    expect(const StrategyArgs(legs: [_leg]), const StrategyArgs(legs: [_leg]));
    expect(
      const StrategyArgs(legs: [_leg]).hashCode,
      const StrategyArgs(legs: [_leg]).hashCode,
    );
    expect(const StrategyArgs(), isNot(const StrategyArgs(legs: [_leg])));
  });
}
