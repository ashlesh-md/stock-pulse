import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Rolling frame/build/raster measurements for the opt-in debug overlay.
class FrameStats extends ChangeNotifier {
  static const capacity = 60;
  final _frames = Queue<({int totalUs, int buildUs, int rasterUs})>();

  int? get framesPerSecond {
    if (_frames.isEmpty) return null;
    final total = _frames.fold<int>(0, (sum, sample) => sum + sample.totalUs);
    if (total <= 0) return null;
    return (_frames.length * Duration.microsecondsPerSecond / total).round();
  }

  double? get averageBuildMs => _average((sample) => sample.buildUs);
  double? get averageRasterMs => _average((sample) => sample.rasterUs);

  double? _average(
    int Function(({int totalUs, int buildUs, int rasterUs})) read,
  ) {
    if (_frames.isEmpty) return null;
    return _frames.fold<int>(0, (sum, sample) => sum + read(sample)) /
        _frames.length /
        Duration.microsecondsPerMillisecond;
  }

  void recordFrame({
    required Duration total,
    required Duration build,
    required Duration raster,
  }) {
    _frames.addLast((
      totalUs: total.inMicroseconds,
      buildUs: build.inMicroseconds,
      rasterUs: raster.inMicroseconds,
    ));
    if (_frames.length > capacity) _frames.removeFirst();
    notifyListeners();
  }

  void recordTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      recordFrame(
        total: timing.totalSpan,
        build: timing.buildDuration,
        raster: timing.rasterDuration,
      );
    }
  }

  String get summary {
    final fps = framesPerSecond?.toString() ?? '—';
    final build = averageBuildMs?.toStringAsFixed(1) ?? '—';
    final raster = averageRasterMs?.toStringAsFixed(1) ?? '—';
    return '$fps FPS · Build $build ms · Raster $raster ms';
  }
}
