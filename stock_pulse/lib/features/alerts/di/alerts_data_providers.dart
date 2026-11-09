import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/features/alerts/data/live_alerts_repository.dart';
import 'package:stock_pulse/features/alerts/domain/alerts_repository.dart';

final alertsRepositoryProvider = Provider<AlertsRepository>(
  (ref) => LiveAlertsRepository(
    ref.watch(apiClientProvider),
    ref.watch(marketSocketProvider),
  ),
);
