import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:stock_pulse/core/observability/domain/crash_reporter.dart';

/// The reporter `bootstrap()` installs: prints in debug and profile and keeps
/// the last [capacity] entries for the debug overlay. Release builds
/// keep the ring only.
class DebugCrashReporter implements CrashReporter {
  DebugCrashReporter({void Function(String line)? printer})
    : _print = printer ?? ((line) => debugPrint(line));

  static const capacity = 100;

  final void Function(String line) _print;
  final _ring = ListQueue<String>(capacity);

  /// Oldest first.
  List<String> get entries => List.unmodifiable(_ring);

  @override
  void recordError(
    Object e,
    StackTrace s, {
    bool fatal = false,
    String? reason,
  }) {
    _add(
      '${fatal ? 'fatal' : 'error'}${reason == null ? '' : ' ($reason)'}: $e',
    );
    if (!kReleaseMode) _print(s.toString());
  }

  @override
  void log(String event, [Map<String, Object?> data = const {}]) =>
      _add(data.isEmpty ? event : '$event $data');

  void _add(String line) {
    if (_ring.length == capacity) _ring.removeFirst();
    _ring.addLast(line);
    if (!kReleaseMode) _print(line);
  }
}

/// Framework errors (a throw in build, layout or paint) are non-fatal; an
/// uncaught async error is fatal. No `runZonedGuarded`: the platform
/// dispatcher hook sees every zone.
void installCrashHooks(CrashReporter r) {
  FlutterError.onError = (details) {
    r.recordError(
      details.exception,
      details.stack ?? StackTrace.empty,
      reason: 'flutter',
    );
    if (!kReleaseMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    r.recordError(error, stack, fatal: true);
    return true;
  };
}
