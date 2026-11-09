import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';

class SettingsController extends AsyncNotifier<LocalPrefsData> {
  @override
  Future<LocalPrefsData> build() async =>
      (await ref.watch(localPrefsProvider.future)).data;
  Future<void> setHaptics({required bool enabled}) =>
      _update((data) => data.copyWith(hapticsEnabled: enabled));
  Future<void> setAnalytics({required bool enabled}) async {
    await _update((data) => data.copyWith(analyticsConsent: enabled));
    if (!enabled && ref.mounted) await ref.read(analyticsProvider).reset();
  }

  Future<void> _update(LocalPrefsData Function(LocalPrefsData) change) async {
    final prefs = await ref.read(localPrefsProvider.future);
    await prefs.update(change);
    if (ref.mounted) state = AsyncData(prefs.data);
  }
}
