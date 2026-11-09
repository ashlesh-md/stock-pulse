import 'dart:ui';

import 'package:flutter/scheduler.dart';

import 'package:stock_pulse/core/observability/data/perf_marks.dart';

/// Paint-latency probe for one instrument. The probed tile or cell
/// calls `PaintProbe.mark(quote.seq)` in build when its seq changes. The id
/// comes from `--dart-define=PERF_PROBE_ID` (default RELIANCE).
abstract final class PaintProbe {
  static const probedId = String.fromEnvironment(
    'PERF_PROBE_ID',
    defaultValue: 'RELIANCE',
  );

  static PaintProbeRecorder? _recorder;

  /// Called by `bootstrap()` only when [kPerfProbe].
  static void install() {
    // coverage:ignore-start
    if (!kPerfProbe || _recorder != null) return;
    final r = PaintProbeRecorder(
      frameNumber: () => PlatformDispatcher.instance.frameData.frameNumber,
      receivedAtUs: PerfMarks.frameReceivedAt,
    );
    _recorder = r;
    SchedulerBinding.instance.addTimingsCallback(r.onTimings);
    // coverage:ignore-end
  }

  static void mark(int seq) {
    // coverage:ignore-start
    if (!kPerfProbe) return;
    _recorder?.onPainted(seq);
    PerfMarks.mark('price_painted', seq: seq);
    // coverage:ignore-end
  }

  static Map<String, Object?> summary() {
    const empty = {'n': 0, 'invalid': 0};
    // coverage:ignore-start
    if (kPerfProbe) return _recorder?.summary() ?? empty;
    // coverage:ignore-end
    return empty;
  }
}

/// Matches a probed paint to the frame that rasterised it and records
/// `rasterFinish − frame_received` in µs.
class PaintProbeRecorder {
  PaintProbeRecorder({required this.frameNumber, required this.receivedAtUs});

  static const maxSamples = 2000;
  static const _maxPending = 64;

  final int Function() frameNumber;
  final int? Function(int seq) receivedAtUs;

  /// frame number → seq painted in it (the last one wins).
  final _pending = <int, int>{};
  final samples = <int>[];

  /// Negative latencies: the two clocks disagree. A run is void over 1 %.
  int invalid = 0;

  void onPainted(int seq) {
    _pending[frameNumber()] = seq;
    if (_pending.length > _maxPending) _pending.remove(_pending.keys.first);
  }

  void onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      final seq = _pending.remove(t.frameNumber);
      if (seq == null) continue;
      final received = receivedAtUs(seq);
      if (received == null) continue;
      final latency =
          t.timestampInMicroseconds(FramePhase.rasterFinish) - received;
      if (latency < 0) {
        invalid++;
      } else if (samples.length < maxSamples) {
        samples.add(latency);
      }
    }
  }

  Map<String, Object?> summary() {
    final sorted = [...samples]..sort();
    // Nearest rank: the smallest sample with at least p of them at or below.
    int? pct(double p) =>
        sorted.isEmpty ? null : sorted[(sorted.length * p).ceil() - 1];
    return {
      'n': sorted.length,
      'p50Us': pct(0.5),
      'p90Us': pct(0.9),
      'invalid': invalid,
    };
  }
}
