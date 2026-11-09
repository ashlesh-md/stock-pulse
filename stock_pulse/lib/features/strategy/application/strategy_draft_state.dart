import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/strategy/domain/strategy_args.dart';

enum AddLegResult { added, full, otherChain }

/// The user's draft built from the chain's "Add to strategy", plus an
/// optional scratch strategy opened from the ticket or an AI card. The
/// builder shows [shownLegs]; a scratch strategy never overwrites [legs].
@immutable
class StrategyDraft {
  StrategyDraft({List<StrategyLeg> legs = const [], List<StrategyLeg>? scratch})
    : legs = List.unmodifiable(legs),
      scratch = scratch == null ? null : List.unmodifiable(scratch);

  static const maxLegs = 4;

  final List<StrategyLeg> legs;
  final List<StrategyLeg>? scratch;

  bool get isScratch => scratch != null;
  List<StrategyLeg> get shownLegs => scratch ?? legs;

  StrategyDraft copyWith({
    List<StrategyLeg>? legs,
    List<StrategyLeg>? Function()? scratch,
  }) => StrategyDraft(
    legs: legs ?? this.legs,
    scratch: scratch == null ? this.scratch : scratch(),
  );

  @override
  bool operator ==(Object other) =>
      other is StrategyDraft &&
      listEquals(other.legs, legs) &&
      listEquals(other.scratch, scratch);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(legs),
    scratch == null ? null : Object.hashAll(scratch!),
  );

  @override
  String toString() => scratch == null
      ? 'StrategyDraft(legs: ${legs.length})'
      : 'StrategyDraft(legs: ${legs.length}, scratch: ${scratch!.length})';
}
