import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';

class RiskNoticeController extends AsyncNotifier<bool> {
  bool _shown = false;

  @override
  Future<bool> build() async {
    final acked = (await ref.watch(localPrefsProvider.future))
        .data
        .riskNoticeAcked;
    if (!acked && !_shown) {
      _shown = true;
      ref.read(analyticsProvider).log(Events.riskNoticeShown);
    }
    return acked;
  }

  Future<void> acknowledge() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final prefs = await ref.read(localPrefsProvider.future);
      await prefs.update((data) => data.copyWith(riskNoticeAcked: true));
      ref.read(analyticsProvider).log(Events.riskNoticeAck);
      return true;
    });
  }
}
