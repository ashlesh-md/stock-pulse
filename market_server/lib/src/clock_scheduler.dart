import 'dart:async';
import 'dart:io';

import 'package:market_server/src/ist.dart';
import 'package:market_server/src/market_calendar.dart';
import 'package:market_server/src/market_clock.dart';

/// Market-time boundaries of a trading day, in firing order:
/// 09:00 dayRoll · 09:15 open · 15:20 squareOff · 15:30 settle · 15:30 close.
enum BoundaryKind { dayRoll, open, squareOff, settle, close }

/// One boundary on one trading day. [key] identifies it for replay guards.
class BoundaryEvent {
  const BoundaryEvent(
    this.kind,
    this.tradingDay,
    this.at, {
    this.fastForward = false,
  });

  final BoundaryKind kind;
  final IstDate tradingDay;

  /// Market time (UTC instant) of the boundary.
  final DateTime at;

  /// True for the single dayRoll that stands in for a skipped span of more
  /// than 10 trading days (flat daily candles).
  final bool fastForward;

  /// e.g. `settle@2026-11-10`.
  String get key => '${kind.name}@$tradingDay';

  @override
  String toString() => 'BoundaryEvent($key${fastForward ? ', ff' : ''})';
}

/// Fires day boundaries exactly once each, in order, however market time
/// moves forward: normal ticking, a jump over minutes, or a jump over days
///.
class ClockScheduler {
  ClockScheduler(
    this._clock,
    this._calendar, {
    bool Function(IstDate day)? isExpiryDay,
  }) : _isExpiryDay =
           isExpiryDay ??
           ((d) =>
               _calendar.expiriesFor('NIFTY', d, count: 1).first.date == d) {
    _lastProcessed = _clock.marketNow();
    _lastPhase = _calendar.phaseAt(_lastProcessed);
  }

  static const _maxReplayDays = 10;
  static const _keepDays = 20;

  final MarketClock _clock;
  final MarketCalendar _calendar;
  final bool Function(IstDate day) _isExpiryDay;
  final Map<BoundaryKind, List<void Function(BoundaryEvent)>> _handlers = {};
  final Map<String, IstDate> _processed = {};
  final _phases = StreamController<MarketPhase>.broadcast(sync: true);
  late DateTime _lastProcessed;
  late MarketPhase _lastPhase;

  /// Market time up to which boundaries have been handled.
  DateTime get lastProcessed => _lastProcessed;

  Stream<MarketPhase> get phaseChanges => _phases.stream;

  /// Handlers run in registration order.
  void on(BoundaryKind kind, void Function(BoundaryEvent e) handler) =>
      (_handlers[kind] ??= []).add(handler);

  /// Called by the engine timer every step and right after a jump.
  void tick() {
    final now = _clock.marketNow();
    if (!now.isAfter(_lastProcessed)) return; // backward jumps: see /debug

    var days = _tradingDaysBetween(Ist.dateOf(_lastProcessed), Ist.dateOf(now));
    if (days.length > _maxReplayDays) {
      final first = days[days.length - _maxReplayDays];
      final at = Ist.at(first, 9, 0);
      _fire(BoundaryEvent(BoundaryKind.dayRoll, first, at, fastForward: true));
      _lastProcessed = at;
      days = days.sublist(days.length - _maxReplayDays);
    }

    for (final day in days) {
      for (final (kind, at) in _boundaries(day)) {
        if (!at.isAfter(_lastProcessed) || at.isAfter(now)) continue;
        if (kind == BoundaryKind.settle && !_isExpiryDay(day)) continue;
        _fire(BoundaryEvent(kind, day, at));
      }
    }
    _lastProcessed = now;

    final phase = _calendar.phaseAt(now);
    if (phase != _lastPhase) {
      _lastPhase = phase;
      _phases.add(phase);
    }
  }

  /// `/debug/reset` only: forgets processed keys and restarts from
  /// [marketTime].
  void resetTo(DateTime marketTime) {
    _processed.clear();
    _lastProcessed = marketTime.toUtc();
    _lastPhase = _calendar.phaseAt(_lastProcessed);
  }

  Future<void> close() => _phases.close();

  void _fire(BoundaryEvent e) {
    if (_processed.containsKey(e.key)) return;
    _processed[e.key] = e.tradingDay;
    _prune(e.tradingDay);
    for (final handler
        in _handlers[e.kind] ?? const <void Function(BoundaryEvent)>[]) {
      try {
        handler(e);
      } on Object catch (error, stack) {
        // One failing handler must not stop the others; the key stays
        // processed so a replay does not run it twice.
        stderr.writeln('scheduler handler failed for ${e.key}: $error\n$stack');
      }
    }
  }

  void _prune(IstDate latest) {
    var cutoff = latest;
    for (var i = 0; i < _keepDays; i++) {
      cutoff = _calendar.previousTradingDay(cutoff);
    }
    _processed.removeWhere((_, day) => day.isBefore(cutoff));
  }

  List<IstDate> _tradingDaysBetween(IstDate from, IstDate to) => [
    for (var d = from; !d.isAfter(to); d = d.addDays(1))
      if (_calendar.isTradingDay(d)) d,
  ];

  static List<(BoundaryKind, DateTime)> _boundaries(IstDate d) => [
    (BoundaryKind.dayRoll, Ist.at(d, 9, 0)),
    (BoundaryKind.open, Ist.at(d, 9, 15)),
    (BoundaryKind.squareOff, Ist.at(d, 15, 20)),
    (BoundaryKind.settle, Ist.at(d, 15, 30)),
    (BoundaryKind.close, Ist.at(d, 15, 30)),
  ];
}
