import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/observability/data/debug_crash_reporter.dart';
import 'package:stock_pulse/core/observability/data/paint_probe.dart';
import 'package:stock_pulse/core/observability/data/perf_marks.dart';

void main() {
  late List<String?> printed;
  late DebugPrintCallback original;

  setUp(() {
    printed = [];
    original = debugPrint;
    debugPrint = (m, {wrapWidth}) => printed.add(m);
    StartupMarks.resetForTest();
  });
  tearDown(() => debugPrint = original);

  test('the default printer goes to debugPrint', () {
    DebugCrashReporter().log('cache_oversize', {'bytes': 1});

    expect(printed, ['cache_oversize {bytes: 1}']);
  });

  test('FR-125: the PERF line prints once', () {
    PerfMarks.mark('main_start');
    StartupMarks.printPerfLineOnce();
    StartupMarks.printPerfLineOnce();

    expect(printed, hasLength(1));
    expect(printed.single, startsWith('PERF {"marks":{"main_start":'));
  });

  test('a named mark that is neither startup nor probe still records', () {
    PerfMarks.mark('custom_mark', seq: 3);
    PerfMarks.mark('custom_mark');

    expect(StartupMarks.values, isEmpty);
    expect(PerfMarks.frameReceivedAt(3), isNull);
  });

  test('without the probe the summary is empty', () {
    PaintProbe.install();

    expect(PaintProbe.summary(), {'n': 0, 'invalid': 0});
  });
}
