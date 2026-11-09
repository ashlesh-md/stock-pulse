import 'package:stock_pulse/core/analytics/domain/analytics_event.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_sink.dart';

/// Records events and resets. Override `analyticsSinksProvider` with
/// `[sink]`, or pass it to `AnalyticsService` directly.
class FakeAnalyticsSink implements AnalyticsSink {
  final events = <AnalyticsEvent>[];
  int resets = 0;

  @override
  String get id => 'fake';

  @override
  Future<void> log(AnalyticsEvent event) async => events.add(event);

  @override
  Future<void> setUserProperty(String name, String? value) async {}

  @override
  Future<void> reset() async => resets++;
}
