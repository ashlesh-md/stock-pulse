import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/features/portfolio/data/live_portfolio_repository.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

final portfolioRepositoryProvider = Provider<PortfolioRepository>(
  (ref) => LivePortfolioRepository(
    ref.watch(apiClientProvider),
    ref.watch(marketSocketProvider),
  ),
);
