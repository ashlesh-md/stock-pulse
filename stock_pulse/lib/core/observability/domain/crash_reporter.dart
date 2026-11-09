/// Error and event sink. A Crashlytics or Sentry reporter would only
/// implement this; none is added.
///
/// `log` events are small and named in snake_case, for example
/// `cache_discarded {reason, bytes}`. Never log tokens or order details.
abstract interface class CrashReporter {
  void recordError(
    Object e,
    StackTrace s, {
    bool fatal = false,
    String? reason,
  });
  void log(String event, [Map<String, Object?> data]);
}
