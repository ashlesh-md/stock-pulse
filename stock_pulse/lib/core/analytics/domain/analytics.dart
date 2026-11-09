import 'package:stock_pulse/core/analytics/domain/analytics_event.dart';

/// Feature-facing analytics contract, independent of vendor sink details.
abstract interface class Analytics {
  void logEvent(AnalyticsEvent event);
  void setScreen(String screen);
  Future<void> setUserProperty(String name, String? value);
  Future<void> reset();
}
