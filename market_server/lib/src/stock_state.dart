import 'package:market_server/src/candle_math.dart';
import 'package:market_server/src/models.dart';
import 'package:market_server/src/tradable.dart';

/// Live state of one stock: the numbers a broker's quote screen shows.
///
/// Two candle series back it:
/// - [minutes]: 1-minute candles for the last few days (intraday charts).
/// - [daily]: one candle per IST day for years (1M … 5Y charts). The LAST
///   daily candle is today, kept live by every trade. Today's open, high,
///   low and volume are read from it, and yesterday's close from the one
///   before.
class StockState implements Tradable {
  StockState(this.instrument) : ltp = instrument.basePrice;

  final Instrument instrument;

  @override
  String get id => instrument.symbol;

  @override
  InstrumentKind get kind => instrument.kind;

  /// Last traded price: the price of the most recent trade.
  @override
  double ltp;

  /// Indicative equilibrium price during pre-open; null otherwise.
  /// Quotes show it in place of [ltp] with `iep: true`.
  double? iep;

  /// Size of the most recent trade.
  int lastQuantity = 0;
  @override
  DateTime lastTradeTime = DateTime.now().toUtc();

  /// Order book, best price first: bids high→low, asks low→high.
  List<DepthLevel> bids = const [];
  List<DepthLevel> asks = const [];

  /// 1-minute candles, oldest first. 5m/15m/1h are built from these.
  final List<Candle> minutes = [];

  /// Daily candles, oldest first; the last one is today. 1w is built from these.
  final List<Candle> daily = [];

  Candle get today => daily.last;
  double get open => today.open;
  double get high => today.high;
  double get low => today.low;
  int get volume => today.volume;

  /// Yesterday's closing price. "Change" and "change %" are measured from it.
  @override
  double get prevClose =>
      daily.length > 1 ? daily[daily.length - 2].close : today.open;

  double get bestBid => bids.isEmpty ? ltp : bids.first.price;
  double get bestAsk => asks.isEmpty ? ltp : asks.first.price;
  @override
  double get change => ltp - prevClose;
  @override
  double get changePercent => prevClose == 0 ? 0 : change / prevClose * 100;

  /// JSON in the requested [mode].
  Map<String, Object?> toQuoteJson(FeedMode mode) {
    final s = this;
    final iep = s.iep;
    final price = iep ?? s.ltp;
    final change = price - s.prevClose;
    final json = <String, Object?>{
      's': s.instrument.symbol,
      'ltp': price,
      'ch': round2(change),
      'chp': round2(s.prevClose == 0 ? 0 : change / s.prevClose * 100),
      't': s.lastTradeTime.millisecondsSinceEpoch,
      if (iep != null) 'iep': true,
    };
    if (mode == FeedMode.ltp) return json;
    json.addAll({
      'o': s.open,
      'h': s.high,
      'l': s.low,
      'pc': s.prevClose,
      'v': s.volume,
      'lq': s.lastQuantity,
      'bid': s.bestBid,
      'ask': s.bestAsk,
    });
    if (mode == FeedMode.full) {
      json['depth'] = {
        'bids': [for (final l in s.bids) l.toJson()],
        'asks': [for (final l in s.asks) l.toJson()],
      };
    }
    return json;
  }
}

/// How much of a quote a subscriber wants. Mirrors the modes real broker
/// feeds offer (Zerodha Kite: ltp / quote / full): smaller modes = fewer bytes.
enum FeedMode { ltp, quote, full }
