import 'package:stock_pulse/app/router/app_route.dart';

/// External links can open read-only screens or a guarded ticket prefill.
Uri? normaliseLink(Uri uri) {
  if (uri.hasScheme &&
      !((uri.scheme == 'stockpulse' && uri.host == 'app') ||
          (uri.scheme == 'https' &&
              uri.host == 'stockpulse.example.com' &&
              !uri.hasPort))) {
    return null;
  }
  if (uri.userInfo.isNotEmpty || (!uri.hasScheme && uri.hasAuthority)) {
    return null;
  }
  final route = AppRoute.fromUri(uri);
  final allowed =
      route is WatchlistRoute ||
      route is OptionChainRoute ||
      route is AiChatRoute ||
      route is PortfolioRoute ||
      route is StockRoute ||
      route is TradeRoute ||
      route is AlertsRoute;
  if (!allowed) return null;
  return Uri.parse(route!.location);
}
