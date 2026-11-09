import 'dart:math' as math;

import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_series.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

class Indicator {
  Indicator(this.spec) {
    if (spec.period < 1 ||
        spec.fast < 1 ||
        spec.slow <= spec.fast ||
        spec.signal < 1 ||
        !spec.deviations.isFinite ||
        spec.deviations <= 0) {
      throw ArgumentError.value(spec);
    }
  }
  final StudySpec spec;
  final _candles = <Candle>[];
  final _lines = <String, List<double?>>{};
  final _fast = <double?>[],
      _slow = <double?>[],
      _gain = <double?>[],
      _loss = <double?>[],
      _pv = <double?>[],
      _volume = <double?>[];
  int writtenIndices = 0;
  bool supportsInterval(CandleInterval interval) =>
      spec.kind != StudyKind.vwap || interval.isIntraday;
  StudySeries get series => StudySeries(
    lines: _lines,
    notEnoughData:
        _lines.isEmpty ||
        _lines.values.every((line) => line.isEmpty || line.last == null),
  );
  StudySeries build(List<Candle> candles) {
    _candles.clear();
    _lines.clear();
    _fast.clear();
    _slow.clear();
    _gain.clear();
    _loss.clear();
    _pv.clear();
    _volume.clear();
    for (final candle in candles) {
      update(candle, append: true);
    }
    return series;
  }

  StudySeries update(Candle candle, {required bool append}) {
    if (!append && _candles.isEmpty) throw StateError('No candle to update');
    if (append) {
      _candles.add(candle);
    } else {
      _candles[_candles.length - 1] = candle;
    }
    final i = _candles.length - 1;
    writtenIndices = 0;
    switch (spec.kind) {
      case StudyKind.sma:
        _write('value', i, _average(i, spec.period));
      case StudyKind.ema:
        _write('value', i, _ema(_lines['value'] ?? [], i, spec.period));
      case StudyKind.vwap:
        _vwap(i);
      case StudyKind.rsi:
        _rsi(i);
      case StudyKind.bollinger:
        final middle = _average(i, spec.period);
        double? deviation;
        if (middle != null) {
          var squares = 0.0;
          for (var j = i - spec.period + 1; j <= i; j++) {
            squares += math.pow(_candles[j].close - middle, 2);
          }
          deviation = math.sqrt(squares / spec.period) * spec.deviations;
        }
        _write('middle', i, middle);
        _write('upper', i, middle == null ? null : middle + deviation!);
        _write('lower', i, middle == null ? null : middle - deviation!);
      case StudyKind.macd:
        _macd(i);
    }
    return series;
  }

  void _write(String key, int i, double? value) {
    _set(_lines.putIfAbsent(key, () => []), i, value);
    writtenIndices++;
  }

  void _set(List<double?> list, int i, double? value) {
    if (list.length == i) {
      list.add(value);
    } else {
      list[i] = value;
    }
  }

  double? _average(int i, int period) {
    if (i + 1 < period) return null;
    var sum = 0.0;
    for (var j = i - period + 1; j <= i; j++) {
      sum += _candles[j].close;
    }
    return sum / period;
  }

  double? _ema(List<double?> output, int i, int period) {
    if (i + 1 < period) return null;
    if (i + 1 == period) return _average(i, period);
    final previous = output[i - 1]!;
    return previous + 2 / (period + 1) * (_candles[i].close - previous);
  }

  int _session(DateTime time) =>
      (time.millisecondsSinceEpoch +
          const Duration(hours: 5, minutes: 30).inMilliseconds -
          const Duration(hours: 9, minutes: 15).inMilliseconds) ~/
      86400000;
  void _vwap(int i) {
    final candle = _candles[i];
    final newSession =
        i == 0 || _session(candle.start) != _session(_candles[i - 1].start);
    final pv =
        (newSession ? 0 : _pv[i - 1]!) +
        (candle.high + candle.low + candle.close) / 3 * candle.volume;
    final volume = (newSession ? 0 : _volume[i - 1]!) + candle.volume;
    _set(_pv, i, pv.toDouble());
    _set(_volume, i, volume.toDouble());
    _write('value', i, volume == 0 ? null : pv / volume);
  }

  void _rsi(int i) {
    if (i < spec.period) {
      _set(_gain, i, null);
      _set(_loss, i, null);
      _write('value', i, null);
      return;
    }
    var gain = 0.0, loss = 0.0;
    if (i == spec.period) {
      for (var j = 1; j <= i; j++) {
        final change = _candles[j].close - _candles[j - 1].close;
        gain += math.max(change, 0);
        loss += math.max(-change, 0);
      }
      gain /= spec.period;
      loss /= spec.period;
    } else {
      final change = _candles[i].close - _candles[i - 1].close;
      gain =
          (_gain[i - 1]! * (spec.period - 1) + math.max(change, 0)) /
          spec.period;
      loss =
          (_loss[i - 1]! * (spec.period - 1) + math.max(-change, 0)) /
          spec.period;
    }
    _set(_gain, i, gain);
    _set(_loss, i, loss);
    _write(
      'value',
      i,
      gain == 0 && loss == 0
          ? 50
          : loss == 0
          ? 100
          : 100 - 100 / (1 + gain / loss),
    );
  }

  void _macd(int i) {
    _set(_fast, i, _ema(_fast, i, spec.fast));
    _set(_slow, i, _ema(_slow, i, spec.slow));
    final line = _fast[i] == null || _slow[i] == null
        ? null
        : _fast[i]! - _slow[i]!;
    _write('line', i, line);
    double? signal;
    if (i >= spec.slow + spec.signal - 2) {
      if (i == spec.slow + spec.signal - 2) {
        signal =
            _lines['line']!
                .skip(spec.slow - 1)
                .cast<double>()
                .reduce((a, b) => a + b) /
            spec.signal;
      } else {
        final previous = _lines['signal']![i - 1]!;
        signal = previous + 2 / (spec.signal + 1) * (line! - previous);
      }
    }
    _write('signal', i, signal);
    _write('histogram', i, signal == null ? null : line! - signal);
  }
}
