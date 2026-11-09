import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/market/data/live_market_repository.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';

final marketRepositoryProvider = Provider<MarketRepository>((ref) {
  final repository = LiveMarketRepository(
    ref.watch(apiClientProvider),
    ref.watch(marketSocketProvider),
    snapshots: ref.watch(snapshotStoreProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});
