import 'package:market_server/src/market_calendar.dart';
import 'package:market_server/src/market_reads.dart';
import 'package:market_server/src/models.dart';
import 'package:option_math/option_math.dart';

Instrument fakeInstrument(String symbol, String name) => Instrument(
  symbol: symbol,
  name: name,
  exchange: 'NSE',
  sector: 'Test',
  basePrice: 100,
);

/// Deterministic [MarketReads] for the ai/ tests: NIFTY (41 strikes, step 50,
/// lot 65, expiry 2026-11-10) and RELIANCE (step 10, lot 500) chains, a few
/// equity quotes and 5-minute candles.
class FakeMarketReads implements MarketReads {
  FakeMarketReads({DateTime? wall, this.marketPhase = MarketPhase.open})
    : wall = wall ?? DateTime.utc(2026, 11, 6, 5, 30);

  DateTime wall;
  MarketPhase marketPhase;

  /// Set to make every read throw (error-path tests).
  Error? throwOnRead;

  /// Ids whose reads return null.
  final missing = <String>{};

  static final expiryAt = DateTime.utc(2026, 11, 10, 10);

  final _list = [
    fakeInstrument('NIFTY', 'Nifty 50'),
    fakeInstrument('RELIANCE', 'Reliance Industries'),
    fakeInstrument('HDFCBANK', 'HDFC Bank'),
    fakeInstrument('TCS', 'Tata Consultancy Services'),
    fakeInstrument('INFY', 'Infosys'),
    fakeInstrument('ITC', 'ITC'),
    fakeInstrument('SBIN', 'State Bank of India'),
  ];

  // (ltp, prevClose)
  static const _prices = {
    'NIFTY': (24512.35, 24480.0),
    'RELIANCE': (1412.35, 1395.6),
    'HDFCBANK': (1001.45, 1005.5),
    'TCS': (3058.9, 3040.0),
    'INFY': (1487.2, 1501.1),
    'ITC': (409.8, 405.0),
    'SBIN': (871.15, 880.0),
  };

  static const _chains = {
    'NIFTY': (centre: 24500, step: 50, lot: 65, iv: 0.13),
    'RELIANCE': (centre: 1400, step: 10, lot: 500, iv: 0.22),
  };

  void _check(String id) {
    if (throwOnRead != null) throw throwOnRead!;
  }

  @override
  DateTime wallNow() => wall;

  @override
  DateTime marketNow() => wall;

  @override
  MarketPhase phase() => marketPhase;

  @override
  Instrument? instrument(String idOrAlias) {
    _check(idOrAlias);
    if (missing.contains(idOrAlias)) return null;
    return _list.where((i) => i.symbol == idOrAlias).firstOrNull;
  }

  @override
  List<Instrument> instruments() => List.unmodifiable(_list);

  @override
  QuoteRead? quote(String id) {
    _check(id);
    final p = _prices[id];
    if (p == null || missing.contains(id)) return null;
    final (ltp, prev) = p;
    final change = ltp - prev;
    return QuoteRead(
      id: id,
      kind: id == 'NIFTY' ? InstrumentKind.marketIndex : InstrumentKind.equity,
      ltp: ltp,
      change: _r2(change),
      changePct: _r2(change / prev * 100),
      prevClose: prev,
      asOf: wall,
    );
  }

  @override
  ChainRead? chainSnapshot(
    String underlying, {
    String? expiry,
    int around = 2,
  }) {
    _check(underlying);
    final cfg = _chains[underlying];
    if (cfg == null || missing.contains('$underlying:chain')) return null;
    if (expiry != null && expiry != '2026-11-10') return null;
    final spot = _prices[underlying]!.$1;
    final strikes = [for (var k = -20; k <= 20; k++) cfg.centre + k * cfg.step];
    final atm = strikes.reduce(
      (a, b) => (b - spot).abs() < (a - spot).abs() ? b : a,
    );
    final years = yearsToExpiry(wall, expiryAt);
    const code = '261110';
    ChainCellRead cell(int k, OptionRight right, int i) => ChainCellRead(
      id: '$underlying-$code-$k-${right.name.toUpperCase()}',
      ltp: _r2(
        bsPrice(
          right: right,
          spot: spot,
          strike: k.toDouble(),
          years: years,
          iv: cfg.iv,
        ),
      ),
      oi: 100000 + (right == OptionRight.ce ? i : 40 - i) * 1000,
      iv: cfg.iv,
    );
    final atmIndex = strikes.indexOf(atm);
    final from = (atmIndex - around).clamp(0, 40);
    final to = (atmIndex + around).clamp(0, 40);
    return ChainRead(
      underlying: underlying,
      expiry: '2026-11-10',
      expiryAt: expiryAt,
      asOf: wall,
      spot: spot,
      pcr: 0.92,
      atm: atm,
      strikeStep: cfg.step,
      lotSize: cfg.lot,
      maxPain: cfg.centre,
      maxCallOiStrike: atm + 4 * cfg.step,
      maxPutOiStrike: atm - 4 * cfg.step,
      rows: [
        for (var i = from; i <= to; i++)
          ChainRowRead(
            strike: strikes[i],
            ce: cell(strikes[i], OptionRight.ce, i),
            pe: cell(strikes[i], OptionRight.pe, i),
          ),
      ],
    );
  }

  @override
  List<String> expiries(String underlying) => _chains.containsKey(underlying)
      ? const ['2026-11-10', '2026-11-17']
      : const [];

  @override
  List<QuoteRead> topMovers(int n, {bool losers = false}) {
    final all =
        [
          for (final id in _prices.keys)
            if (id != 'NIFTY') quote(id)!,
        ]..sort(
          (a, b) => losers
              ? a.changePct.compareTo(b.changePct)
              : b.changePct.compareTo(a.changePct),
        );
    return all.take(n).toList();
  }

  @override
  List<Candle> candles(String id, Duration interval, {int limit = 75}) {
    _check(id);
    final p = _prices[id];
    if (p == null) return const [];
    final start = DateTime.utc(2026, 11, 6, 3, 45);
    return [
      for (var i = 0; i < 80; i++)
        Candle(
          start: start.add(interval * i),
          open: p.$2 + i * 0.1,
          high: p.$2 + i * 0.1 + 1,
          low: p.$2 + i * 0.1 - 1,
          close: p.$2 + i * 0.1 + 0.05,
          volume: 1000,
        ),
    ].reversed.take(limit).toList().reversed.toList();
  }
}

double _r2(double v) => (v * 100).roundToDouble() / 100;
