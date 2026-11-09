import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;

/// One leg of a strategy as the user picked it.
///
/// Contract metadata (right, strike, expiry, lot size) is never stored here:
/// it is read from instrument metadata by [contractId].
@immutable
class StrategyLeg {
  const StrategyLeg({
    required this.contractId,
    required this.side,
    required this.lots,
    required this.premium,
  });

  final String contractId;
  final OrderSide side;
  final int lots;

  /// Entry premium per unit, taken from the caller (the chain cell LTP).
  final double premium;

  StrategyLeg copyWith({OrderSide? side, int? lots, double? premium}) =>
      StrategyLeg(
        contractId: contractId,
        side: side ?? this.side,
        lots: lots ?? this.lots,
        premium: premium ?? this.premium,
      );

  @override
  bool operator ==(Object other) =>
      other is StrategyLeg &&
      other.contractId == contractId &&
      other.side == side &&
      other.lots == lots &&
      other.premium == premium;

  @override
  int get hashCode => Object.hash(contractId, side, lots, premium);

  @override
  String toString() =>
      'StrategyLeg($contractId, ${side.name}, $lots lot(s), $premium)';
}

/// Arguments of `openStrategyBuilder`. Empty [legs] opens the user's draft;
/// any legs open a scratch strategy that leaves the draft alone.
@immutable
class StrategyArgs {
  const StrategyArgs({this.legs = const []});

  final List<StrategyLeg> legs;

  @override
  bool operator ==(Object other) =>
      other is StrategyArgs && listEquals(other.legs, legs);

  @override
  int get hashCode => Object.hashAll(legs);
}

/// `UNDERLYING-YYMMDD` from an option id like `NIFTY-261110-24500-CE`.
/// The underlying may itself contain `-`, so strike and right are dropped
/// from the end. An id without them is returned as is.
String chainKeyOf(String contractId) {
  final parts = contractId.split('-');
  if (parts.length < 4) return contractId;
  return parts.sublist(0, parts.length - 2).join('-');
}
