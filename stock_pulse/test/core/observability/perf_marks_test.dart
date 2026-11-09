import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/observability/data/paint_probe.dart';
import 'package:stock_pulse/core/observability/data/perf_marks.dart';

FrameTiming timing({required int frame, required int rasterFinishUs}) =>
    FrameTiming(
      vsyncStart: 0,
      buildStart: 0,
      buildFinish: 0,
      rasterStart: 0,
      rasterFinish: rasterFinishUs,
      rasterFinishWallTime: rasterFinishUs,
      frameNumber: frame,
    );

void main() {
  setUp(StartupMarks.resetForTest);

  test('startup marks are once-only: the 2nd cache_painted is ignored', () {
    PerfMarks.mark('cache_painted');
    final first = StartupMarks.values['cache_painted'];
    PerfMarks.mark('cache_painted');

    expect(first, isNotNull);
    expect(StartupMarks.values['cache_painted'], first);
  });

  test('probe marks are no-ops without PERF_PROBE', () {
    expect(kPerfProbe, isFalse);
    PerfMarks.mark('frame_received', seq: 7);
    PaintProbe.mark(7);

    expect(PerfMarks.frameReceivedAt(7), isNull);
    expect(StartupMarks.values, isEmpty);
  });

  test('the PERF line holds every recorded mark as JSON', () {
    PerfMarks.mark('main_start');
    PerfMarks.mark('cache_read_done');

    final line = StartupMarks.perfLine();
    expect(line, startsWith('PERF {"marks":{"main_start":'));
    expect(line, contains('"cache_read_done":'));
  });

  test('PaintProbeRecorder: latency = rasterFinish - frame_received', () {
    var frame = 10;
    final received = {5: 1000, 6: 2000, 7: 9000};
    final r = PaintProbeRecorder(
      frameNumber: () => frame,
      receivedAtUs: (seq) => received[seq],
    );

    r.onPainted(5); // frame 10
    frame = 11;
    r.onPainted(6);
    frame = 12;
    r.onPainted(7);
    r.onTimings([
      timing(frame: 10, rasterFinishUs: 1500), // 500 us
      timing(frame: 11, rasterFinishUs: 2900), // 900 us
      timing(frame: 12, rasterFinishUs: 8000), // negative: clocks disagree
      timing(frame: 99, rasterFinishUs: 1), // not probed
    ]);

    expect(r.samples, [500, 900]);
    expect(r.invalid, 1);
    final s = r.summary();
    expect(s['n'], 2);
    expect(s['invalid'], 1);
    expect(s['p50Us'], 500);
    expect(s['p90Us'], 900);
  });
}
