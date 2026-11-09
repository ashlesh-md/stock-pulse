import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';

/// Live available funds for order tickets and account surfaces.
final portfolioFundsProvider = StreamProvider.autoDispose<Funds>(
  (ref) => ref.watch(portfolioRepositoryProvider).watchFunds(),
);
