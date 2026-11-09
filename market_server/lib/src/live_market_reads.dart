import 'package:market_server/src/broker.dart';
import 'package:market_server/src/instruments.dart' show underlyingConfigs;
import 'package:market_server/src/market_calendar.dart';
import 'package:market_server/src/market_clock.dart';
import 'package:market_server/src/market_engine.dart';
import 'package:market_server/src/market_reads.dart';
import 'package:market_server/src/models.dart';
import 'package:market_server/src/option_book.dart';

class LiveMarketReads implements MarketReads {
  LiveMarketReads(this._engine, this._options, this._clock);
  final MarketEngine _engine;
  final OptionBook _options;
  final MarketClock _clock;
  @override
  DateTime wallNow() => _clock.wallNow();
  @override
  DateTime marketNow() => _clock.marketNow();
  @override
  MarketPhase phase() => _engine.phase;
  @override
  Instrument? instrument(String idOrAlias) =>
      _engine[idOrAlias.toUpperCase()]?.instrument;
  @override
  List<Instrument> instruments() =>
      List.unmodifiable([for (final stock in _engine.stocks) stock.instrument]);
  @override
  QuoteRead? quote(String id) {
    final stock = _engine[id];
    if (stock == null) return null;
    return QuoteRead(
      id: stock.id,
      kind: stock.instrument.kind,
      ltp: stock.ltp,
      change: stock.ltp - stock.prevClose,
      changePct: (stock.ltp - stock.prevClose) / stock.prevClose * 100,
      prevClose: stock.prevClose,
      asOf: wallNow(),
    );
  }

  @override
  List<String> expiries(String underlying) {
    try {
      return [
        for (final expiry in _options.expiries(underlying))
          expiry['code']! as String,
      ];
    } on OrderRejection {
      return const [];
    }
  }

  @override
  ChainRead? chainSnapshot(
    String underlying, {
    String? expiry,
    int around = 2,
  }) {
    final list = expiries(underlying);
    if (list.isEmpty) return null;
    expiry ??= list.first;
    Map<String, Object?> json;
    try {
      json = _options.chain(underlying, expiry);
    } on OrderRejection {
      return null;
    }
    final step = _engine[underlying]!.instrument.strikeStep!;
    final atm = json['atm']! as int;
    ChainCellRead cell(Map<String, Object?> data) => ChainCellRead(
      id: data['contractId']! as String,
      ltp: (data['ltp']! as num).toDouble(),
      oi: data['oi']! as int,
      iv: (data['iv']! as num).toDouble(),
    );
    final allRows = [
      for (final raw in json['rows']! as List)
        if (raw is Map<String, Object?>)
          ChainRowRead(
            strike: raw['strike']! as int,
            ce: cell(raw['ce']! as Map<String, Object?>),
            pe: cell(raw['pe']! as Map<String, Object?>),
          ),
    ];
    final rows = [
      for (final row in allRows)
        if ((row.strike - atm).abs() <= around * step) row,
    ];
    if (rows.isEmpty) return null;
    final calls = allRows.fold<int>(0, (sum, row) => sum + row.ce.oi);
    final puts = allRows.fold<int>(0, (sum, row) => sum + row.pe.oi);
    return ChainRead(
      underlying: underlying,
      expiry: expiry,
      expiryAt: DateTime.parse('${expiry}T10:00:00Z'),
      asOf: wallNow(),
      spot: (json['spot']! as num).toDouble(),
      pcr: calls == 0 ? 0 : puts / calls,
      atm: atm,
      strikeStep: step,
      lotSize: underlyingConfigs[underlying]!.lotSize,
      maxPain: _maxPainStrike(allRows),
      maxCallOiStrike: allRows
          .reduce((a, b) => a.ce.oi > b.ce.oi ? a : b)
          .strike,
      maxPutOiStrike: allRows
          .reduce((a, b) => a.pe.oi > b.pe.oi ? a : b)
          .strike,
      rows: rows,
    );
  }

  int _maxPainStrike(List<ChainRowRead> rows) {
    var minimumPayout = double.infinity;
    var maxPain = rows.first.strike;
    for (final candidate in rows) {
      final settlement = candidate.strike;
      var payout = 0.0;
      for (final row in rows) {
        if (settlement > row.strike) {
          payout += (settlement - row.strike) * row.ce.oi;
        } else if (settlement < row.strike) {
          payout += (row.strike - settlement) * row.pe.oi;
        }
      }
      if (payout < minimumPayout) {
        minimumPayout = payout;
        maxPain = settlement;
      }
    }
    return maxPain;
  }

  @override
  List<QuoteRead> topMovers(int n, {bool losers = false}) {
    final quotes = [
      for (final stock in _engine.stocks)
        if (stock.instrument.kind == InstrumentKind.equity) quote(stock.id)!,
    ];
    quotes.sort(
      (a, b) => losers
          ? a.changePct.compareTo(b.changePct)
          : b.changePct.compareTo(a.changePct),
    );
    return List.unmodifiable(quotes.take(n));
  }

  @override
  List<Candle> candles(String id, Duration interval, {int limit = 75}) =>
      List.unmodifiable([
        for (final candle in _engine.candles(id, interval, limit: limit))
          Candle(
            start: candle.start,
            open: candle.open,
            high: candle.high,
            low: candle.low,
            close: candle.close,
            volume: candle.volume,
          ),
      ]);
}
