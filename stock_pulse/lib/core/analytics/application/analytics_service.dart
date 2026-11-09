import 'dart:async';

import 'package:stock_pulse/core/analytics/domain/analytics.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_event.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_sink.dart';
import 'package:stock_pulse/core/observability/domain/crash_reporter.dart';

final class AnalyticsService implements Analytics {
  AnalyticsService(this._sinks, this._reporter, {required this.consent});
  final List<AnalyticsSink> _sinks;
  final CrashReporter _reporter;
  final bool Function() consent;
  final Set<String> _reported = {};

  @override
  void logEvent(AnalyticsEvent event) {
    if (!consent() || !event.isValid) return;
    final copy = AnalyticsEvent(event.name, Map.unmodifiable(event.params));
    for (final sink in _sinks) {
      unawaited(_guard(sink, () => sink.log(copy)));
    }
  }

  /// Kept as a source-compatible alias while feature callers migrate.
  void log(AnalyticsEvent event) => logEvent(event);

  @override
  void setScreen(String screen) => logEvent(Events.screenView(screen));

  @override
  Future<void> setUserProperty(String name, String? value) async {
    if (!consent() || !_isSafeProperty(name, value)) return;
    await Future.wait([
      for (final sink in _sinks)
        _guard(sink, () => sink.setUserProperty(name, value)),
    ]);
  }

  bool _isSafeProperty(String name, String? value) =>
      RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(name) &&
      !_sensitiveKeys.contains(name) &&
      (value == null || value.length <= 64);

  static const _sensitiveKeys = {
    'prompt',
    'prompt_text',
    'email',
    'token',
    'account_id',
    'message',
    'text',
    'amount',
    'price',
  };

  @override
  Future<void> reset() =>
      Future.wait([for (final sink in _sinks) _guard(sink, sink.reset)]);
  Future<void> _guard(
    AnalyticsSink sink,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object catch (error, stack) {
      if (_reported.add(sink.id)) {
        _reporter.recordError(error, stack, reason: 'analytics_sink_failed');
      }
    }
  }
}
