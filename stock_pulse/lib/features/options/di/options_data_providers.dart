import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/features/options/data/live_chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_repository.dart';

final chainRepositoryProvider = Provider<ChainRepository>(
  (ref) => LiveChainRepository(
    ref.watch(apiClientProvider),
    ref.watch(marketSocketProvider),
  ),
);
