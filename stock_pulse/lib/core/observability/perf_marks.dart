import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import 'package:stock_pulse/core/observability/data/paint_probe.dart';

/// Compiled in only with `--dart-define=PERF_PROBE=true`.
const kPerfProbe = bool.fromEnvironment('PERF_PROBE');

/// Named timeline marks. Every `Timeline` call in `lib/` goes through here
/// or `PaintProbe`, so a CI grep can keep timeline noise out of screens.
///
/// Startup marks ([StartupMarks.names]) are always on and once-only. Probe
/// marks (`frame_received`, `price_painted`, `ai_first_card_painted`,
/// `ai_stream_done`) return at once unless [kPerfProbe].
abstract final class PerfMarks {
  static const _probeMarks = {
    'frame_received',
    'price_painted',
    'ai_first_card_painted',
    'ai_stream_done',
  };

  /// `frame_received` µs per seq, last [_receivedCap] seqs, for [PaintProbe].
  static const _receivedCap = 64;
  static final _received = <int, int>{}; // insertion-ordered

  static void mark(String name, {int? seq}) {
    if (StartupMarks.names.contains(name)) {
      if (!StartupMarks._record(name, Timeline.now)) return;
      Timeline.instantSync(name);
      if (name == 'first_live_tick_painted') StartupMarks.printPerfLineOnce();
      return;
    }
    if (!kPerfProbe && _probeMarks.contains(name)) return;
    // coverage:ignore-start
    if (kPerfProbe && name == 'frame_received' && seq != null) {
      _received[seq] = Timeline.now;
      if (_received.length > _receivedCap) {
        _received.remove(_received.keys.first);
      }
    }
    // coverage:ignore-end
    Timeline.instantSync(name, arguments: seq == null ? null : {'seq': seq});
  }

  /// When `frame_received(seq)` was marked, in `Timeline.now` µs.
  static int? frameReceivedAt(int seq) => _received[seq];
}

/// The once-only startup marks and the single `PERF` log line, read by the perf scripts.
abstract final class StartupMarks {
  static const names = {
    'main_start',
    'cache_read_done',
    'cache_painted',
    'socket_welcome',
    'first_live_tick_painted',
  };

  static final _values = <String, int>{};
  static bool _printed = false;

  /// Mark name → `Timeline.now` µs, in the order they were set.
  static Map<String, int> get values => Map.unmodifiable(_values);

  /// Elapsed milliseconds from the bootstrap mark to the current frame.
  static int? get elapsedSinceMainStartMs {
    final start = _values['main_start'];
    return start == null ? null : (Timeline.now - start) ~/ 1000;
  }

  static bool _record(String name, int us) {
    if (_values.containsKey(name)) return false;
    _values[name] = us;
    return true;
  }

  /// `PERF {"marks":{...},"probe":{...}}`, read by `tool/perf/*.sh`.
  static String perfLine() =>
      'PERF ${jsonEncode({'marks': _values, if (kPerfProbe) 'probe': PaintProbe.summary()})}';

  /// At `first_live_tick_painted` or 10 s after `main_start`, whichever is
  /// first. Never in release builds.
  static void printPerfLineOnce() {
    if (_printed || kReleaseMode) return;
    _printed = true;
    debugPrint(perfLine());
  }

  @visibleForTesting
  static void resetForTest() {
    _values.clear();
    _printed = false;
    PerfMarks._received.clear();
  }
}
