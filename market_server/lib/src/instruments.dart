import 'package:market_server/src/market_calendar.dart';

export 'package:market_server/src/instrument_table.dart';
export 'package:market_server/src/models.dart' show InstrumentKind;

/// Watchlist a fresh install starts with.
const defaultWatchlist = <String>['NIFTY', 'RELIANCE', 'HDFCBANK'];

/// Option settings per underlying that has a chain.
class UnderlyingConfig {
  const UnderlyingConfig({
    required this.symbol,
    required this.strikeStep,
    required this.lotSize,
    required this.expiryKind,
    required this.baseAtmIv,
    required this.skew,
    required this.curv,
  });

  final String symbol;
  final int strikeStep;

  /// Contract lot size (units per lot). Options only; read it from here or
  /// from instrument JSON, never from a constant.
  final int lotSize;
  final ExpiryKind expiryKind;
  final double baseAtmIv;
  final double skew;
  final double curv;
}

const underlyingConfigs = <String, UnderlyingConfig>{
  'NIFTY': UnderlyingConfig(
    symbol: 'NIFTY',
    strikeStep: 50,
    lotSize: 65,
    expiryKind: ExpiryKind.weekly,
    baseAtmIv: 0.13,
    skew: -0.12,
    curv: 0.04,
  ),
  'RELIANCE': UnderlyingConfig(
    symbol: 'RELIANCE',
    strikeStep: 10,
    lotSize: 500,
    expiryKind: ExpiryKind.monthly,
    baseAtmIv: 0.22,
    skew: -0.08,
    curv: 0.04,
  ),
  'HDFCBANK': UnderlyingConfig(
    symbol: 'HDFCBANK',
    strikeStep: 10,
    lotSize: 550,
    expiryKind: ExpiryKind.monthly,
    baseAtmIv: 0.20,
    skew: -0.08,
    curv: 0.04,
  ),
};
