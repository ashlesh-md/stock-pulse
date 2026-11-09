import 'package:stock_pulse/core/observability/domain/crash_reporter.dart';

typedef RecordedError = ({
  Object error,
  StackTrace stack,
  bool fatal,
  String? reason,
});
typedef RecordedLog = ({String event, Map<String, Object?> data});

/// Records every call. Override `crashReporterProvider` with it.
class FakeCrashReporter implements CrashReporter {
  final errors = <RecordedError>[];
  final logs = <RecordedLog>[];

  @override
  void recordError(
    Object e,
    StackTrace s, {
    bool fatal = false,
    String? reason,
  }) => errors.add((error: e, stack: s, fatal: fatal, reason: reason));

  @override
  void log(String event, [Map<String, Object?> data = const {}]) =>
      logs.add((event: event, data: data));

  /// Logs with this event name, for example `logsNamed('cache_discarded')`.
  List<RecordedLog> logsNamed(String event) =>
      logs.where((l) => l.event == event).toList();
}
