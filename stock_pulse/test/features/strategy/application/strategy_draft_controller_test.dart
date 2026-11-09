import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart'
    show ReplyToSender;
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/strategy/application/strategy_draft_controller.dart';
import 'package:stock_pulse/features/strategy/application/strategy_draft_state.dart';
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';

StrategyLeg _leg(String contractId, {double premium = 100}) => StrategyLeg(
  contractId: contractId,
  side: OrderSide.buy,
  lots: 1,
  premium: premium,
);

void main() {
  late ProviderContainer container;
  late StrategyDraftController draft;
  StrategyDraft state() => container.read(strategyDraftControllerProvider);

  setUp(() {
    container = ProviderContainer.test();
    draft = container.read(strategyDraftControllerProvider.notifier);
  });

  test('starts empty in draft mode', () {
    expect(state(), StrategyDraft());
    expect(state().isScratch, isFalse);
    expect(state().shownLegs, isEmpty);
  });

  group('addLeg (U1: FR-29, FR-71, D5)', () {
    test('added: appends the leg with the caller premium and 1 lot', () {
      expect(
        draft.addLeg('NIFTY-261110-24500-CE', OrderSide.buy, 120.5),
        AddLegResult.added,
      );
      expect(state().legs, [_leg('NIFTY-261110-24500-CE', premium: 120.5)]);
    });

    test('full: a 5th leg changes nothing', () {
      for (final strike in [24400, 24500, 24600, 24700]) {
        draft.addLeg('NIFTY-261110-$strike-CE', OrderSide.sell, 10);
      }
      final before = state();
      expect(
        draft.addLeg('NIFTY-261110-24800-CE', OrderSide.buy, 5),
        AddLegResult.full,
      );
      expect(state(), before);
    });

    test('otherChain: another underlying or expiry changes nothing', () {
      draft.addLeg('NIFTY-261110-24500-CE', OrderSide.buy, 100);
      final before = state();
      expect(
        draft.addLeg('BANKNIFTY-261110-52000-PE', OrderSide.buy, 90),
        AddLegResult.otherChain,
      );
      expect(
        draft.addLeg('NIFTY-261117-24500-PE', OrderSide.buy, 90),
        AddLegResult.otherChain,
      );
      expect(state(), before);
    });

    test(
      'other chain offers Start new without changing the draft first',
      () async {
        draft.addLeg('NIFTY-261110-24500-CE', OrderSide.buy, 100);
        final before = state();

        expect(
          draft.addFromChain('BANKNIFTY-261110-52000-PE', OrderSide.sell, 90),
          AddLegResult.otherChain,
        );
        expect(state(), before);
        final message = container.read(feedbackControllerProvider)!;
        expect(message.actionLabel, 'Start new');
        expect(message.action, const ReplyToSender('start_new'));

        container
            .read(feedbackControllerProvider.notifier)
            .actionTapped(message);
        await container.pump();

        expect(state().legs, [
          _leg(
            'BANKNIFTY-261110-52000-PE',
            premium: 90,
          ).copyWith(side: OrderSide.sell),
        ]);
      },
    );

    test('full add shows the capacity message and preserves the draft', () {
      for (final strike in [24400, 24500, 24600, 24700]) {
        draft.addLeg('NIFTY-261110-$strike-CE', OrderSide.sell, 10);
      }
      final before = state();

      expect(
        draft.addFromChain('NIFTY-261110-24800-CE', OrderSide.buy, 5),
        AddLegResult.full,
      );
      expect(state(), before);
      expect(
        container.read(feedbackControllerProvider)?.text,
        'Up to 4 legs in preview',
      );
    });

    test('a hyphenated underlying stays one chain', () {
      draft.addLeg('BAJAJ-AUTO-261127-9000-CE', OrderSide.buy, 50);
      expect(
        draft.addLeg('BAJAJ-AUTO-261127-9100-PE', OrderSide.sell, 40),
        AddLegResult.added,
      );
      expect(
        draft.addLeg('AUTO-261127-9100-PE', OrderSide.sell, 40),
        AddLegResult.otherChain,
      );
    });

    test('clear then addLeg gives added on the new chain', () {
      draft
        ..addLeg('NIFTY-261110-24500-CE', OrderSide.buy, 100)
        ..clear();
      expect(state().legs, isEmpty);
      expect(
        draft.addLeg('BANKNIFTY-261110-52000-PE', OrderSide.sell, 90),
        AddLegResult.added,
      );
      expect(state().legs.single.contractId, 'BANKNIFTY-261110-52000-PE');
    });

    test('goes to the draft even while a scratch strategy is shown', () {
      draft
        ..load(StrategyArgs(legs: [_leg('RELIANCE-261126-1500-CE')]))
        ..addLeg('NIFTY-261110-24500-CE', OrderSide.buy, 100);
      expect(state().legs.single.contractId, 'NIFTY-261110-24500-CE');
      expect(state().shownLegs.single.contractId, 'RELIANCE-261126-1500-CE');
    });
  });

  group('load (C7)', () {
    test('legs open a scratch strategy and keep the draft (W10)', () {
      draft.addLeg('NIFTY-261110-24500-CE', OrderSide.buy, 100);
      final scratch = [_leg('NIFTY-261110-24600-PE', premium: 80)];
      draft.load(StrategyArgs(legs: scratch));
      expect(state().isScratch, isTrue);
      expect(state().shownLegs, scratch);
      expect(state().legs, [_leg('NIFTY-261110-24500-CE')]);
    });

    test('empty args show the draft again', () {
      draft
        ..addLeg('NIFTY-261110-24500-CE', OrderSide.buy, 100)
        ..load(StrategyArgs(legs: [_leg('NIFTY-261110-24600-PE')]))
        ..load(const StrategyArgs());
      expect(state().isScratch, isFalse);
      expect(state().shownLegs, [_leg('NIFTY-261110-24500-CE')]);
    });

    test('keeps at most 4 scratch legs', () {
      draft.load(
        StrategyArgs(
          legs: [
            for (final strike in [1, 2, 3, 4, 5]) _leg('X-261110-$strike-CE'),
          ],
        ),
      );
      expect(state().shownLegs, hasLength(StrategyDraft.maxLegs));
    });
  });

  group('update and remove edit the shown legs', () {
    test('in draft mode', () {
      draft
        ..addLeg('NIFTY-261110-24500-CE', OrderSide.buy, 100)
        ..addLeg('NIFTY-261110-24600-CE', OrderSide.buy, 60)
        ..update(1, side: OrderSide.sell, lots: 3);
      expect(state().legs[1].side, OrderSide.sell);
      expect(state().legs[1].lots, 3);
      draft.remove(0);
      expect(state().legs.single.contractId, 'NIFTY-261110-24600-CE');
    });

    test('in scratch mode, leaving the draft alone', () {
      draft
        ..addLeg('NIFTY-261110-24500-CE', OrderSide.buy, 100)
        ..load(
          StrategyArgs(
            legs: [
              _leg('NIFTY-261110-24600-PE'),
              _leg('NIFTY-261110-24700-PE'),
            ],
          ),
        )
        ..update(0, lots: 2)
        ..remove(1);
      expect(state().shownLegs, [
        _leg('NIFTY-261110-24600-PE').copyWith(lots: 2),
      ]);
      expect(state().legs, [_leg('NIFTY-261110-24500-CE')]);
    });
  });

  test('legs lists are unmodifiable', () {
    draft
      ..addLeg('NIFTY-261110-24500-CE', OrderSide.buy, 100)
      ..load(StrategyArgs(legs: [_leg('NIFTY-261110-24600-PE')]));
    expect(() => state().legs.add(state().legs.first), throwsUnsupportedError);
    expect(
      () => state().shownLegs.add(state().legs.first),
      throwsUnsupportedError,
    );
  });

  test('clear on an empty draft keeps the same state', () {
    final before = state();
    draft.clear();
    expect(identical(state(), before), isTrue);
  });

  test('the draft outlives its listeners (keep-alive)', () async {
    final sub = container.listen(strategyDraftControllerProvider, (_, _) {});
    draft.addLeg('NIFTY-261110-24500-CE', OrderSide.buy, 100);
    sub.close();
    await container.pump();
    expect(state().legs, hasLength(1));
  });
}
