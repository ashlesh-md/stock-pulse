import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/di/l10n_providers.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/strategy/application/strategy_draft_state.dart';
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';

class StrategyDraftController extends Notifier<StrategyDraft> {
  StrategyLeg? _pendingStartNew;
  StreamSubscription<FeedbackReply>? _feedbackReplies;

  @override
  StrategyDraft build() {
    _feedbackReplies = ref
        .read(feedbackControllerProvider.notifier)
        .replies
        .listen(_onFeedbackReply);
    ref.onDispose(() => unawaited(_feedbackReplies?.cancel()));
    return StrategyDraft();
  }

  /// Appends to the draft with [premium] and 1 lot. `full` and `otherChain`
  /// change nothing; the caller decides whether to [clear] and retry.
  AddLegResult addLeg(String contractId, OrderSide side, double premium) {
    final legs = state.legs;
    if (legs.length >= StrategyDraft.maxLegs) return AddLegResult.full;
    if (legs.isNotEmpty &&
        chainKeyOf(legs.first.contractId) != chainKeyOf(contractId)) {
      return AddLegResult.otherChain;
    }
    final leg = StrategyLeg(
      contractId: contractId,
      side: side,
      lots: 1,
      premium: premium,
    );
    state = state.copyWith(legs: [...legs, leg]);
    return AddLegResult.added;
  }

  AddLegResult addFromChain(String contractId, OrderSide side, double premium) {
    final result = addLeg(contractId, side, premium);
    final strings = ref.read(stringsProvider).options;
    final feedback = ref.read(feedbackControllerProvider.notifier);
    switch (result) {
      case AddLegResult.added:
        feedback.show(
          FeedbackMessage(
            key: 'strategy.added.$contractId',
            text: strings.strategyAdded,
            kind: FeedbackKind.success,
            actionLabel: strings.viewStrategy,
            action: const OpenLocation(StrategyRoute.path),
          ),
        );
      case AddLegResult.full:
        feedback.show(
          FeedbackMessage(key: 'strategy.full', text: strings.strategyFull),
        );
      case AddLegResult.otherChain:
        _pendingStartNew = StrategyLeg(
          contractId: contractId,
          side: side,
          lots: 1,
          premium: premium,
        );
        feedback.show(
          FeedbackMessage(
            key: 'strategy.other_chain',
            text: strings.strategyOtherChain(
              chainKeyOf(state.shownLegs.first.contractId),
            ),
            actionLabel: strings.startNew,
            action: const ReplyToSender('start_new'),
          ),
        );
    }
    return result;
  }

  void _onFeedbackReply(FeedbackReply reply) {
    if (reply.key != 'strategy.other_chain' || reply.actionId != 'start_new') {
      return;
    }
    final next = _pendingStartNew;
    if (next == null) return;
    _pendingStartNew = null;
    clear();
    addFromChain(next.contractId, next.side, next.premium);
  }

  /// Empty `args.legs` shows the draft; otherwise the legs open as a scratch
  /// strategy, capped at [StrategyDraft.maxLegs].
  void load(StrategyArgs args) {
    final scratch = args.legs.isEmpty
        ? null
        : args.legs.take(StrategyDraft.maxLegs).toList();
    state = state.copyWith(scratch: () => scratch);
  }

  void update(int index, {OrderSide? side, int? lots}) {
    final next = [...state.shownLegs];
    next[index] = next[index].copyWith(side: side, lots: lots);
    _setShown(next);
  }

  void remove(int index) => _setShown([...state.shownLegs]..removeAt(index));

  void clear() {
    if (!state.isScratch && state.legs.isEmpty) return;
    state = state.copyWith(legs: const [], scratch: () => null);
  }

  void _setShown(List<StrategyLeg> legs) {
    state = state.isScratch
        ? state.copyWith(scratch: () => legs)
        : state.copyWith(legs: legs);
  }
}
