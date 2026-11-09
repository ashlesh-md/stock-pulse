import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/strategy/application/strategy_draft_state.dart';
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';

const _a = StrategyLeg(
  contractId: 'NIFTY-261110-24500-CE',
  side: OrderSide.buy,
  lots: 1,
  premium: 100,
);
const _b = StrategyLeg(
  contractId: 'NIFTY-261110-24600-PE',
  side: OrderSide.sell,
  lots: 2,
  premium: 80,
);

void main() {
  test('is equal by draft and scratch legs', () {
    expect(StrategyDraft(legs: [_a]), StrategyDraft(legs: [_a]));
    expect(
      StrategyDraft(legs: [_a], scratch: [_b]).hashCode,
      StrategyDraft(legs: [_a], scratch: [_b]).hashCode,
    );
    expect(StrategyDraft(legs: [_a]), isNot(StrategyDraft(scratch: [_a])));
    expect(StrategyDraft(legs: [_a]), isNot(StrategyDraft(legs: [_b])));
  });

  test('copyWith keeps the fields it is not given', () {
    final draft = StrategyDraft(legs: [_a], scratch: [_b]);
    expect(draft.copyWith(), draft);
    expect(draft.copyWith(legs: [_b]).scratch, [_b]);
    expect(draft.copyWith(scratch: () => null).isScratch, isFalse);
    expect(draft.copyWith(scratch: () => null).legs, [_a]);
  });

  test('toString shows the leg counts', () {
    expect(
      StrategyDraft(legs: [_a], scratch: [_a, _b]).toString(),
      'StrategyDraft(legs: 1, scratch: 2)',
    );
    expect(StrategyDraft().toString(), 'StrategyDraft(legs: 0)');
  });
}
