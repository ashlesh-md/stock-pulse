import 'package:go_router/go_router.dart';
import 'package:stock_pulse/features/orders/domain/order.dart'
    show OrderSide, ProductType;
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart'
    show OrderSource, OrderTicketArgs;
import 'package:stock_pulse/features/portfolio/domain/portfolio_section.dart';

part 'detail_routes.dart';

/// Every screen the router can show. Screens never build paths: they pass a
/// route to `context.goTo` / `context.pushTo`.
part 'shell_routes.dart';

sealed class AppRoute {
  const AppRoute();

  /// Bare `/`, which redirects to the watchlist.
  static const rootPath = '/';

  /// Path plus query, ready for `GoRouter.go`.
  String get location;

  /// True for the five shell tabs, which are selected, never pushed.
  bool get isTab => this is ShellRoute;

  @override
  bool operator ==(Object other) =>
      other is AppRoute &&
      other.runtimeType == runtimeType &&
      other.location == location;

  @override
  int get hashCode => location.hashCode;

  /// The route a link or push points at; null when no screen matches.
  static AppRoute? fromUri(Uri uri) {
    final segments = uri.pathSegments;
    final query = uri.queryParameters;
    return switch (uri.path) {
      rootPath || WatchlistRoute.path => const WatchlistRoute(),
      OptionChainRoute.path => OptionChainRoute.fromQuery(query),
      AiChatRoute.path => const AiChatRoute(),
      AlertsRoute.path => const AlertsRoute(),
      PortfolioRoute.path => PortfolioRoute.fromQuery(query),
      MoreRoute.path => const MoreRoute(),
      SocketLabRoute.path => const SocketLabRoute(),
      AddFundsRoute.path => const AddFundsRoute(),
      DebugClockRoute.path => const DebugClockRoute(),
      StrategyRoute.path => const StrategyRoute(),
      _ => switch (segments) {
        ['trade', final id] when id.isNotEmpty => TradeRoute.fromQuery(
          id,
          query,
        ),
        ['order', final id] when id.isNotEmpty => OrderTicketRoute.fromQuery(
          id,
          query,
        ),
        ['stock', final id] when id.isNotEmpty => StockRoute(id),
        _ => null,
      },
    };
  }
}

String? _nonEmpty(String? s) => s == null || s.isEmpty ? null : s;

String _withQuery(String path, Map<String, String> query) =>
    Uri(path: path, queryParameters: query.isEmpty ? null : query).toString();
