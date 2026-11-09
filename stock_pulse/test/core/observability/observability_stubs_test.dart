import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/observability/data/paint_probe.dart';
import 'package:stock_pulse/core/observability/data/perf_marks.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';

import '../../helpers/fake_crash_reporter.dart';

void main() {
  test('crashReporterProvider must be overridden', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(() => container.read(crashReporterProvider), throwsA(anything));
  });

  test('FakeCrashReporter records errors and logs', () {
    final fake = FakeCrashReporter();
    final container = ProviderContainer(
      overrides: [crashReporterProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final reporter = container.read(crashReporterProvider);
    reporter.recordError(
      StateError('x'),
      StackTrace.empty,
      fatal: true,
      reason: 'test',
    );
    reporter.log('cache_discarded', {'reason': 'old', 'bytes': 10});

    expect(fake.errors.single.fatal, isTrue);
    expect(fake.errors.single.reason, 'test');
    expect(fake.logs.single.event, 'cache_discarded');
    expect(fake.logs.single.data, {'reason': 'old', 'bytes': 10});
  });

  test('marks never throw; probe marks are off without PERF_PROBE', () {
    expect(kPerfProbe, isFalse);
    PerfMarks.mark('main_start');
    PerfMarks.mark('frame_received', seq: 1);
    PaintProbe.mark(1);
  });
}
