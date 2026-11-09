import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:stock_pulse/app/di/layout_providers.dart';
import 'package:stock_pulse/app/layout/window_class.dart';
import 'package:stock_pulse/app/router/app_route.dart';

/// The only way screens navigate between routes.
extension AppNavigation on BuildContext {
  /// Replaces the stack: a tab route selects that tab and drops every route
  /// above the shell.
  void goTo(AppRoute route) => GoRouter.of(this).goTo(route);

  /// Pushes [route] above the current one; a tab route is selected instead.
  /// A stock page on top is replaced, so two never stack. On an expanded
  /// window a stock opened from the watchlist fills its detail pane instead.
  Future<T?> pushTo<T extends Object?>(AppRoute route) async {
    final router = GoRouter.of(this);
    if (route.isTab) {
      router.goTo(route);
      return null;
    }
    if (route is StockRoute) {
      final name = router.state.name;
      if (name == WatchlistRoute.name && windowClass.showsTwoPanes) {
        ProviderScope.containerOf(
          this,
          listen: false,
        ).read(stockPaneProvider.notifier).show(route.instrumentId);
        return null;
      }
      if (name == StockRoute.name) {
        return router.pushReplacement<T>(route.location);
      }
    }
    return router.push<T>(route.location);
  }
}

/// For code that holds the router rather than a context, such as app hosts.
extension AppRouterNavigation on GoRouter {
  void goTo(AppRoute route) => go(route.location);
}
