import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/data/debug_analytics_sink.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_sink.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';

final analyticsSinksProvider = Provider<List<AnalyticsSink>>(
  (ref) => [if (kDebugMode) DebugAnalyticsSink()],
);
final analyticsProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(
    ref.watch(analyticsSinksProvider),
    ref.watch(crashReporterProvider),
    consent: () =>
        ref.read(localPrefsProvider).value?.data.analyticsConsent ?? false,
  ),
);
