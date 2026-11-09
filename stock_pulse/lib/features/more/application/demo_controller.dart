import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';

class DemoController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);
  Future<void> setClock(DateTime time) async {
    state = const AsyncLoading();
    final result = await ref.read(debugClientProvider).setClock(time);
    if (!ref.mounted) return;
    state = switch (result) {
      Success() => const AsyncData(null),
      Failure(:final error) => AsyncError(error, StackTrace.current),
    };
  }

  Future<void> reset({DateTime? time}) async {
    state = const AsyncLoading();
    final result = await ref.read(debugClientProvider).reset(marketTime: time);
    if (!ref.mounted) return;
    if (result case Failure(:final error)) {
      state = AsyncError(error, StackTrace.current);
      return;
    }
    final prefs = await ref.read(localPrefsProvider.future);
    await Future.wait([
      prefs.clear(),
      ref.read(snapshotStoreProvider).clear(),
      ref.read(analyticsProvider).reset(),
    ]);
    if (!ref.mounted) return;
    ref.invalidate(localPrefsProvider);
    ref.invalidate(marketRepositoryProvider);
    ref.invalidate(portfolioRepositoryProvider);
    state = const AsyncData(null);
  }
}
