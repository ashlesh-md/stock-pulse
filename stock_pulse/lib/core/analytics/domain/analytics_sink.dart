import 'package:stock_pulse/core/analytics/domain/analytics_event.dart';

abstract interface class AnalyticsSink {
  String get id;
  Future<void> log(AnalyticsEvent event);
  Future<void> setUserProperty(String name, String? value);
  Future<void> reset();
}
