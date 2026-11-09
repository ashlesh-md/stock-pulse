import 'package:market_server/src/market_calendar.dart';
import 'package:market_server/src/models.dart';

/// Read-only quote view for `ai/`.
class QuoteRead {
  const QuoteRead({
    required this.id,
    required this.kind,
    required this.ltp,
    required this.change,
    required this.changePct,
    required this.prevClose,
    required this.asOf,
  });

  final String id;
  final InstrumentKind kind;
  final double ltp;
  final double change;
  final double changePct;
  final double prevClose;

  /// `MarketReads.wallNow()` at the read.
  final DateTime asOf;
}

class ChainCellRead {
  const ChainCellRead({
    required this.id,
    required this.ltp,
    required this.oi,
    required this.iv,
  });

  final String id;
  final double ltp;
  final int oi;
  final double iv;
}

class ChainRowRead {
  const ChainRowRead({
    required this.strike,
    required this.ce,
    required this.pe,
  });

  final int strike;
  final ChainCellRead ce;
  final ChainCellRead pe;
}

class ChainRead {
  ChainRead({
    required this.underlying,
    required this.expiry,
    required this.expiryAt,
    required this.asOf,
    required this.spot,
    required this.pcr,
    required this.atm,
    required this.strikeStep,
    required this.lotSize,
    required this.maxPain,
    required this.maxCallOiStrike,
    required this.maxPutOiStrike,
    required List<ChainRowRead> rows,
  }) : rows = List.unmodifiable(rows);

  final String underlying;
  final String expiry;
  final DateTime expiryAt;
  final DateTime asOf;
  final double spot;

  /// Σ put OI / Σ call OI over all strikes.
  final double pcr;
  final int atm;
  final int strikeStep;
  final int lotSize;
  final int maxPain;
  final int maxCallOiStrike;
  final int maxPutOiStrike;
  final List<ChainRowRead> rows;
}

/// Read-only facade over the market for the `ai/` module. No method mutates
/// state; `ai/` imports only this file.
abstract interface class MarketReads {
  DateTime wallNow();
  DateTime marketNow();
  MarketPhase phase();
  Instrument? instrument(String idOrAlias);
  List<Instrument> instruments();
  QuoteRead? quote(String id);

  /// [expiry] null = nearest.
  ChainRead? chainSnapshot(String underlying, {String? expiry, int around = 2});
  List<String> expiries(String underlying);

  /// Equities only, by changePct.
  List<QuoteRead> topMovers(int n, {bool losers = false});
  List<Candle> candles(String id, Duration interval, {int limit = 75});
}
