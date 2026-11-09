import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/layout/max_width_box.dart';
import 'package:stock_pulse/app/layout/watchlist_two_pane.dart';
import 'package:stock_pulse/app/layout/window_class.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/app_shell_scaffold.dart';
import 'package:stock_pulse/app/router/deep_link.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/ai_chat/presentation/screens/ai_chat_screen.dart';
import 'package:stock_pulse/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:stock_pulse/features/market/presentation/screens/stock_detail_screen.dart';
import 'package:stock_pulse/features/more/presentation/screens/add_funds_screen.dart';
import 'package:stock_pulse/features/more/presentation/screens/debug_clock_screen.dart';
import 'package:stock_pulse/features/more/presentation/screens/more_screen.dart';
import 'package:stock_pulse/features/more/presentation/screens/socket_lab_screen.dart';
import 'package:stock_pulse/features/options/presentation/screens/chain_screen.dart';
import 'package:stock_pulse/features/orders/presentation/screens/order_ticket_screen.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_section.dart';
import 'package:stock_pulse/features/portfolio/presentation/screens/portfolio_screen.dart';
import 'package:stock_pulse/features/strategy/presentation/screens/strategy_builder_screen.dart';

/// The app's route table. Branches build on first visit and stay built;
/// routes above the shell sit on the root navigator, where [observers]
/// see them. An unknown location goes to the watchlist.
GoRouter buildAppRouter({
  List<NavigatorObserver> observers = const [],
  String initialLocation = WatchlistRoute.path,
  void Function()? onInvalidLink,
  void Function(Uri link)? onDeepLinkOpened,
}) {
  final root = GlobalKey<NavigatorState>(debugLabel: 'root');
  final pendingExternalStockPaths = <String>{};
  return GoRouter(
    navigatorKey: root,
    initialLocation: initialLocation,
    observers: observers,
    redirect: (_, state) {
      if (!state.uri.hasScheme) return null;
      final normalized = normaliseLink(state.uri);
      final path = normalized?.toString();
      if (normalized != null) {
        onDeepLinkOpened?.call(state.uri);
        if (normalized.path.startsWith('/stock/')) {
          pendingExternalStockPaths.add(normalized.path);
        }
      }
      if (path == null) onInvalidLink?.call();
      return path ?? WatchlistRoute.path;
    },
    onException: (_, _, router) {
      onInvalidLink?.call();
      router.go(WatchlistRoute.path);
    },
    routes: [
      GoRoute(path: AppRoute.rootPath, redirect: (_, _) => WatchlistRoute.path),
      StatefulShellRoute.indexedStack(
        // Branch pages are tabs, which visibility reads from the shell index.
        notifyRootObserver: false,
        pageBuilder: (_, _, shell) => MaterialPage<void>(
          name: kShellPageName,
          child: AppShellScaffold(navigationShell: shell),
        ),
        branches: [
          _branch(
            WatchlistRoute.path,
            WatchlistRoute.name,
            (_, _) => const WatchlistTwoPane(),
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: OptionChainRoute.path,
                name: OptionChainRoute.name,
                pageBuilder: (_, state) {
                  final target = OptionChainRoute.fromState(state);
                  return NoTransitionPage<void>(
                    key: state.pageKey,
                    child: MaxWidthBox(
                      maxWidth: ContentWidth.table,
                      child: ChainScreen(
                        underlying: target.underlying,
                        expiry: target.expiry,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          _branch(
            AiChatRoute.path,
            AiChatRoute.name,
            (_, _) => const MaxWidthBox(
              maxWidth: ContentWidth.list,
              child: AiChatScreen(),
            ),
          ),
          _branch(
            PortfolioRoute.path,
            PortfolioRoute.name,
            (_, state) => MaxWidthBox(
              maxWidth: ContentWidth.list,
              child: PortfolioScreen(
                initialSection:
                    PortfolioRoute.fromState(state).section ??
                    PortfolioSection.positions,
              ),
            ),
          ),
          _branch(
            MoreRoute.path,
            MoreRoute.name,
            (_, _) => const MaxWidthBox(
              maxWidth: ContentWidth.list,
              child: MoreScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: StockRoute.path,
        name: StockRoute.name,
        parentNavigatorKey: root,
        builder: (_, state) => MaxWidthBox(
          maxWidth: ContentWidth.table,
          child: StockDetailScreen(
            instrumentId: StockRoute.fromState(state).instrumentId,
            isExternalLink: pendingExternalStockPaths.remove(state.uri.path),
          ),
        ),
      ),
      GoRoute(
        path: StrategyRoute.path,
        name: StrategyRoute.name,
        parentNavigatorKey: root,
        builder: (_, _) => const MaxWidthBox(
          maxWidth: ContentWidth.list,
          child: StrategyBuilderScreen(),
        ),
      ),
      GoRoute(
        path: AddFundsRoute.path,
        name: AddFundsRoute.name,
        parentNavigatorKey: root,
        builder: (_, _) => const MaxWidthBox(
          maxWidth: ContentWidth.list,
          child: AddFundsScreen(),
        ),
      ),
      GoRoute(
        path: DebugClockRoute.path,
        name: DebugClockRoute.name,
        parentNavigatorKey: root,
        builder: (_, _) => const MaxWidthBox(
          maxWidth: ContentWidth.list,
          child: DebugClockScreen(),
        ),
      ),
      GoRoute(
        path: OrderTicketRoute.path,
        name: OrderTicketRoute.name,
        parentNavigatorKey: root,
        builder: (_, state) => MaxWidthBox(
          maxWidth: ContentWidth.list,
          child: OrderTicketScreen(
            args: OrderTicketRoute.fromState(state).args,
          ),
        ),
      ),
      GoRoute(
        path: AlertsRoute.path,
        name: AlertsRoute.name,
        parentNavigatorKey: root,
        builder: (_, _) => const MaxWidthBox(
          maxWidth: ContentWidth.list,
          child: AlertsScreen(),
        ),
      ),
      GoRoute(
        path: SocketLabRoute.path,
        name: SocketLabRoute.name,
        parentNavigatorKey: root,
        builder: (_, _) => const MaxWidthBox(
          maxWidth: ContentWidth.list,
          child: SocketLabScreen(),
        ),
      ),
    ],
  );
}

StatefulShellBranch _branch(
  String path,
  String name,
  GoRouterWidgetBuilder builder,
) => StatefulShellBranch(
  routes: [GoRoute(path: path, name: name, builder: builder)],
);
