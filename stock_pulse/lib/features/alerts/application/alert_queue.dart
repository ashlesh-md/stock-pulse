import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/alerts/di/alerts_data_providers.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';

class AlertQueue extends Notifier<List<PriceAlert>> {
  final _seen = <String>{};
  @override
  List<PriceAlert> build() {
    final sub = ref
        .watch(alertsRepositoryProvider)
        .triggered
        .listen(
          (alert) => unawaited(_enqueue(alert)),
          // A failed alert fetch only means no banner; the Alerts screen
          // shows the error. Unhandled, it would crash the app zone.
          onError: (Object _) {},
        );
    ref.onDispose(sub.cancel);
    return const [];
  }

  Future<void> _enqueue(PriceAlert alert) async {
    final prefs = await ref.read(localPrefsProvider.future);
    if (!ref.mounted ||
        _seen.contains(alert.alertId) ||
        prefs.data.seenAlertIds.contains(alert.alertId)) {
      return;
    }
    _seen.add(alert.alertId);
    state = [...state, alert];
    await prefs.update(
      (data) =>
          data.copyWith(seenAlertIds: {...data.seenAlertIds, alert.alertId}),
    );
  }

  void dismiss() {
    if (state.isNotEmpty) state = state.skip(1).toList();
  }
}
