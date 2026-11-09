import 'dart:async';

import 'package:market_server/src/ist.dart';
import 'package:market_server/src/market_calendar.dart';

/// `demo` starts the market at 10:00 IST on a trading day; `real` follows the
/// wall clock.
enum ClockMode { demo, real }

/// Emitted when market time is moved by [MarketClock.jumpTo].
class ClockJump {
  const ClockJump(this.fromMarket, this.toMarket);
  final DateTime fromMarket;
  final DateTime toMarket;
}

/// Two clocks in one: wall time for transport (serverTime, asOf,
/// staleness, keep-alive) and market time = wall + offset for trading logic
/// (phase, candles, expiry, order times).
class MarketClock {
  MarketClock({
    required this.mode,
    DateTime Function()? wall,
    Duration initialOffset = Duration.zero,
  }) : _wall = wall ?? DateTime.now,
       _offset = initialOffset,
       _overridden = mode == ClockMode.demo;

  /// Demo mode: market time starts at 10:00:00 IST on today's IST
  /// date if it is a trading day, else on the next trading day, so the
  /// market is Open whenever a demo runs. Wall time is unchanged.
  static MarketClock demo(MarketCalendar cal, {DateTime Function()? wall}) {
    final wallFn = wall ?? DateTime.now;
    final now = wallFn().toUtc();
    final today = Ist.dateOf(now);
    final day = cal.isTradingDay(today) ? today : cal.nextTradingDay(today);
    return MarketClock(
      mode: ClockMode.demo,
      wall: wallFn,
      initialOffset: Ist.at(day, 10, 0).difference(now),
    );
  }

  final ClockMode mode;
  final DateTime Function() _wall;
  final _jumps = StreamController<ClockJump>.broadcast(sync: true);
  Duration _offset;
  bool _overridden;

  /// UTC wall time.
  DateTime wallNow() => _wall().toUtc();

  /// UTC market time: [wallNow] + [marketOffset].
  DateTime marketNow() => wallNow().add(_offset);

  Duration get marketOffset => _offset;

  /// True in demo mode or after any [jumpTo] ("Demo clock" chip).
  bool get overridden => _overridden;

  Stream<ClockJump> get jumps => _jumps.stream;

  /// Moves market time only; wall time is unchanged.
  void jumpTo(DateTime marketTime) {
    final from = marketNow();
    _offset = marketTime.toUtc().difference(wallNow());
    _overridden = true;
    _jumps.add(ClockJump(from, marketNow()));
  }

  /// Waits [d] of wall time.
  Future<void> delay(Duration d) => Future<void>.delayed(d);

  Future<void> close() => _jumps.close();
}

/// Test clock: time moves only on [advance], and [delay] futures
/// complete when advanced past their due time, in due order.
class FakeMarketClock extends MarketClock {
  FakeMarketClock._(this._now, Duration offset, ClockMode mode)
    : super(mode: mode, initialOffset: offset);

  factory FakeMarketClock({
    required DateTime wallStart,
    DateTime? marketStart,
    ClockMode mode = ClockMode.real,
  }) {
    final wall = wallStart.toUtc();
    final offset = marketStart == null
        ? Duration.zero
        : marketStart.toUtc().difference(wall);
    return FakeMarketClock._(_Box(wall), offset, mode);
  }

  final _Box _now;
  final List<_Delay> _delays = [];
  int _order = 0;

  @override
  DateTime wallNow() => _now.value;

  @override
  Future<void> delay(Duration d) {
    final pending = _Delay(_now.value.add(d), _order++);
    _delays.add(pending);
    return pending.completer.future;
  }

  /// Moves wall time (market follows) and completes due [delay] futures.
  void advance(Duration d) {
    _now.value = _now.value.add(d);
    final due = _delays.where((x) => !x.at.isAfter(_now.value)).toList()
      ..sort((a, b) {
        final byTime = a.at.compareTo(b.at);
        return byTime != 0 ? byTime : a.order.compareTo(b.order);
      });
    for (final x in due) {
      _delays.remove(x);
      x.completer.complete();
    }
  }
}

class _Box {
  _Box(this.value);
  DateTime value;
}

class _Delay {
  _Delay(this.at, this.order);
  final DateTime at;
  final int order;
  final completer = Completer<void>();
}

/// Body of the `clock` frame, `welcome.clock` and `GET /clock`
///. Times are ms since epoch; `serverTime` is wall,
/// `marketTime` and `nextPhaseAt` are market time. `tradingDay` is today's
/// IST market date, or the last trading day on a weekend or holiday.
Map<String, Object?> clockJson(MarketClock clock, MarketCalendar calendar) {
  final market = clock.marketNow();
  final today = Ist.dateOf(market);
  final tradingDay = calendar.isTradingDay(today)
      ? today
      : calendar.previousTradingDay(today);
  return {
    'serverTime': clock.wallNow().millisecondsSinceEpoch,
    'marketTime': market.millisecondsSinceEpoch,
    'marketOffsetMs': clock.marketOffset.inMilliseconds,
    'phase': calendar.phaseAt(market).name,
    'mode': clock.mode.name,
    'overridden': clock.overridden,
    'tradingDay': tradingDay.toString(),
    'nextPhaseAt': calendar
        .nextPhaseChangeAfter(market)
        ?.millisecondsSinceEpoch,
  };
}
