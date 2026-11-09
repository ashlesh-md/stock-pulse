import 'dart:collection';

import 'package:stock_pulse/core/analytics/domain/analytics_event.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_sink.dart';

final class DebugAnalyticsSink implements AnalyticsSink {
  final _events = Queue<AnalyticsEvent>();
  List<AnalyticsEvent> get events => List.unmodifiable(_events);
  @override
  String get id => 'debug';
  @override
  Future<void> log(AnalyticsEvent event) async {
    _events.add(event);
    if (_events.length > 200) _events.removeFirst();
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {}
  @override
  Future<void> reset() async => _events.clear();
}
