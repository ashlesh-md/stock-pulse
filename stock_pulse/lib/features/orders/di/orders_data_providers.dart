import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/orders/data/live_order_repository.dart';
import 'package:stock_pulse/features/orders/data/local_pending_order_store.dart';
import 'package:stock_pulse/features/orders/domain/order_repository.dart';
import 'package:stock_pulse/features/orders/domain/pending_order_store.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  final repository = LiveOrderRepository(
    ref.watch(apiClientProvider),
    ref.watch(marketSocketProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final pendingOrderStoreProvider = FutureProvider<PendingOrderStore>((
  ref,
) async {
  final prefs = await ref.watch(localPrefsProvider.future);
  return LocalPendingOrderStore(prefs);
});
