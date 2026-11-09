import 'package:option_math/option_math.dart';

/// Strategies the AI can draw a payoff for. [phrase] is how a question names
/// it; [label] is the card title.
enum StrategyKind {
  longCall('long call', 'Long call'),
  shortCall('short call', 'Short call'),
  longPut('long put', 'Long put'),
  shortPut('short put', 'Short put'),
  straddle('straddle', 'Long straddle'),
  shortStraddle('short straddle', 'Short straddle'),
  strangle('strangle', 'Long strangle'),
  shortStrangle('short strangle', 'Short strangle'),
  bullCallSpread('bull call spread', 'Bull call spread'),
  bearPutSpread('bear put spread', 'Bear put spread'),
  ironCondor('iron condor', 'Iron condor');

  const StrategyKind(this.phrase, this.label);

  final String phrase;
  final String label;
}

/// One leg relative to the anchor strike. [strike] is already resolved.
class LegTemplate {
  const LegTemplate({
    required this.right,
    required this.strikeOffsetSteps,
    required this.side,
    required this.strike,
    this.lots = 1,
  });

  final OptionRight right;
  final int strikeOffsetSteps;
  final LegSide side;
  final int strike;
  final int lots;
}

/// The question's strike snapped to [step] (ties go to the lower strike, as
/// ATM does).
int snapStrike(int strike, int step) {
  final below = (strike ~/ step) * step;
  return strike - below > step / 2 ? below + step : below;
}

/// Legs of [kind] around [anchorStrike] (ATM or the snapped question
/// strike), 1 lot each.
List<LegTemplate> legsFor(StrategyKind kind, int anchorStrike, int strikeStep) {
  LegTemplate leg(OptionRight right, int steps, LegSide side) => LegTemplate(
    right: right,
    strikeOffsetSteps: steps,
    side: side,
    strike: anchorStrike + steps * strikeStep,
  );
  const ce = OptionRight.ce, pe = OptionRight.pe;
  const buy = LegSide.buy, sell = LegSide.sell;
  return switch (kind) {
    StrategyKind.longCall => [leg(ce, 0, buy)],
    StrategyKind.shortCall => [leg(ce, 0, sell)],
    StrategyKind.longPut => [leg(pe, 0, buy)],
    StrategyKind.shortPut => [leg(pe, 0, sell)],
    StrategyKind.straddle => [leg(ce, 0, buy), leg(pe, 0, buy)],
    StrategyKind.shortStraddle => [leg(ce, 0, sell), leg(pe, 0, sell)],
    StrategyKind.strangle => [leg(ce, 2, buy), leg(pe, -2, buy)],
    StrategyKind.shortStrangle => [leg(ce, 2, sell), leg(pe, -2, sell)],
    StrategyKind.bullCallSpread => [leg(ce, 0, buy), leg(ce, 2, sell)],
    StrategyKind.bearPutSpread => [leg(pe, 0, buy), leg(pe, -2, sell)],
    StrategyKind.ironCondor => [
      leg(pe, -2, sell),
      leg(pe, -4, buy),
      leg(ce, 2, sell),
      leg(ce, 4, buy),
    ],
  };
}
