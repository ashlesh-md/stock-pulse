import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/features/portfolio/application/order_announcer.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_controller.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_state.dart';

final portfolioControllerProvider =
    AsyncNotifierProvider.autoDispose<PortfolioController, PortfolioState>(
      PortfolioController.new,
    );

/// Kept alive by `OrderUpdateListener` above every route.
final orderAnnouncerProvider = NotifierProvider<OrderAnnouncer, void>(
  OrderAnnouncer.new,
);
