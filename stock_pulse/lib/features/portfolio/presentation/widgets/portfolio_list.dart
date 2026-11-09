import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/widgets/empty_view.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_section.dart';
import 'package:stock_pulse/features/portfolio/domain/position.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/order_tile.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/pnl_card.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/position_detail_sheet.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/position_tile.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/section_header.dart';

/// The P&L card and the rows of one [section], built lazily. It rebuilds
/// when the section's list changes, never on a price tick.
class PortfolioList extends ConsumerWidget {
  const PortfolioList({
    super.key,
    required this.section,
    this.refreshEnabled = true,
  });
  final PortfolioSection section;
  final bool refreshEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = switch (section) {
      PortfolioSection.positions => _positions(context, ref),
      PortfolioSection.holdings => _holdings(context, ref),
      PortfolioSection.orders => _orders(context, ref),
    };
    return ListView.builder(
      key: PageStorageKey(section),
      physics: refreshEnabled
          ? const AlwaysScrollableScrollPhysics()
          : const NoOverscrollScrollPhysics(),
      itemCount: rows.length + 1,
      itemBuilder: (context, index) =>
          index == 0 ? PnlCard(section: section) : rows[index - 1](context),
    );
  }

  List<WidgetBuilder> _positions(BuildContext context, WidgetRef ref) {
    final s = context.strings.portfolio;
    final positions = ref.watch(
      portfolioControllerProvider.select((a) => a.value?.positions ?? const []),
    );
    return [
      (_) => SectionHeader(s.positionsHeader(positions.length)),
      if (positions.isEmpty)
        (context) => _empty(context, s.positions, s.noPositions),
      for (final p in positions) (context) => _tile(context, p),
    ];
  }

  List<WidgetBuilder> _holdings(BuildContext context, WidgetRef ref) {
    final s = context.strings.portfolio;
    final (holdings, loading, failed) = ref.watch(
      portfolioControllerProvider.select(
        (a) => (
          a.value?.holdings ?? const [],
          a.value?.loadingHoldings ?? false,
          a.value?.holdingsFailed ?? false,
        ),
      ),
    );
    return [
      if (loading)
        (_) => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      if (failed)
        (context) => EmptyView(
          icon: AppIcons.offline,
          title: s.holdings,
          message: s.holdingsFailed,
          actionLabel: context.strings.common.retry,
          onAction: ref.read(portfolioControllerProvider.notifier).loadHoldings,
        ),
      if (!loading && !failed && holdings.isEmpty)
        (context) => _empty(context, s.holdings, s.noHoldings),
      for (final h in holdings)
        (context) => _tile(
          context,
          Position(
            symbol: h.symbol,
            quantity: h.quantity,
            averagePrice: h.averagePrice,
            realizedPnl: 0,
          ),
        ),
    ];
  }

  List<WidgetBuilder> _orders(BuildContext context, WidgetRef ref) {
    final s = context.strings.portfolio;
    final orders = ref.watch(
      portfolioControllerProvider.select((a) => a.value?.orders ?? const []),
    );
    final controller = ref.read(portfolioControllerProvider.notifier);
    final offline =
        ref.watch(networkStatusProvider).value == NetworkStatus.offline;
    return [
      (_) => SectionHeader(s.ordersHeader(orders.length)),
      if (orders.isEmpty) (_) => ListTile(title: Text(s.noOrders)),
      for (final o in orders)
        (_) => OrderTile(
          order: o,
          onCancel: () => controller.cancel(o.id),
          onRefreshStatus: () => controller.refreshPendingStatus(o),
          waitingForConnection: offline,
        ),
    ];
  }

  Widget _empty(BuildContext context, String title, String message) =>
      EmptyView(
        icon: AppIcons.watchlist,
        title: title,
        message: message,
        actionLabel: context.strings.portfolio.goToWatchlist,
        onAction: () => context.goTo(const WatchlistRoute()),
      );

  Widget _tile(BuildContext context, Position position) => PositionTile(
    key: ValueKey(position.key),
    position: position,
    onTap: () => showPositionDetails(context, position: position),
  );
}

/// Keeps ordinary scrolling while preventing pull-to-refresh overscroll.
class NoOverscrollScrollPhysics extends ScrollPhysics {
  const NoOverscrollScrollPhysics({super.parent});

  @override
  NoOverscrollScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      NoOverscrollScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.minScrollExtent) {
      return value - position.minScrollExtent;
    }
    if (value > position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }
    return 0;
  }
}
