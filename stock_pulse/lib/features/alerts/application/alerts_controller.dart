import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/features/alerts/di/alerts_data_providers.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';

class AlertsController extends StreamNotifier<List<PriceAlert>> {
  @override
  Stream<List<PriceAlert>> build() =>
      ref.watch(alertsRepositoryProvider).watchAll();
  Future<bool> create(
    String symbol,
    AlertCondition condition,
    double level,
  ) async {
    if (symbol.trim().isEmpty || !level.isFinite || level <= 0) return false;
    final result = await ref
        .read(alertsRepositoryProvider)
        .create(symbol.trim(), condition, level);
    if (!ref.mounted) return false;
    if (result case Success(:final value)) {
      final current = state.value ?? const <PriceAlert>[];
      state = AsyncData([
        value,
        ...current.where((a) => a.alertId != value.alertId),
      ]);
      ref.read(analyticsProvider).log(Events.alertCreated(condition.name));
      return true;
    }
    return false;
  }

  Future<bool> cancel(String id) async {
    final result = await ref.read(alertsRepositoryProvider).delete(id);
    if (!ref.mounted) return false;
    if (result case Success(:final value)) {
      state = AsyncData([
        for (final alert in state.value ?? const <PriceAlert>[])
          alert.alertId == id ? value : alert,
      ]);
      return true;
    }
    return false;
  }
}
