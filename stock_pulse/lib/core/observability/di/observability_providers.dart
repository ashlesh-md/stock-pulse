import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/core/observability/domain/crash_reporter.dart';

/// Overridden in `bootstrap()` with the instance the crash hooks use, so
/// tests must override it too (`FakeCrashReporter`).
final crashReporterProvider = Provider<CrashReporter>(
  (ref) => throw UnimplementedError(
    'crashReporterProvider is overridden in bootstrap(); '
    'override it with FakeCrashReporter in tests',
  ),
);

/// Session-only developer overlay switch; it never changes release behavior.
final debugOverlayProvider = NotifierProvider<DebugOverlayController, bool>(
  DebugOverlayController.new,
);

class DebugOverlayController extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled({required bool enabled}) => state = enabled;
}
