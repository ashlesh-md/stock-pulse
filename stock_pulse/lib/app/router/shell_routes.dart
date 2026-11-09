part of 'app_route.dart';

sealed class ShellRoute extends AppRoute {
  const ShellRoute();
}

final class WatchlistRoute extends ShellRoute {
  const WatchlistRoute();

  static const path = '/watchlist';
  static const name = 'watchlist';

  @override
  String get location => path;
}

final class OptionChainRoute extends ShellRoute {
  const OptionChainRoute({this.underlying, this.expiry});

  /// Unknown keys are ignored; empty values read as absent.
  factory OptionChainRoute.fromQuery(Map<String, String> q) => OptionChainRoute(
    underlying: _nonEmpty(q['u']),
    expiry: _nonEmpty(q['e']),
  );

  factory OptionChainRoute.fromState(GoRouterState state) =>
      OptionChainRoute.fromQuery(state.uri.queryParameters);

  static const path = '/options';
  static const name = 'options';

  final String? underlying;

  /// `yyyy-MM-dd`; null opens the nearest expiry.
  final String? expiry;

  @override
  String get location => _withQuery(path, {'u': ?underlying, 'e': ?expiry});
}

final class AiChatRoute extends ShellRoute {
  const AiChatRoute();

  static const path = '/ai';
  static const name = 'ai';

  @override
  String get location => path;
}

final class PortfolioRoute extends ShellRoute {
  const PortfolioRoute({this.section});

  /// An unknown `tab` value reads as no tab.
  factory PortfolioRoute.fromQuery(Map<String, String> q) =>
      PortfolioRoute(section: PortfolioSection.values.asNameMap()[q['tab']]);

  factory PortfolioRoute.fromState(GoRouterState state) =>
      PortfolioRoute.fromQuery(state.uri.queryParameters);

  static const path = '/portfolio';
  static const name = 'portfolio';

  final PortfolioSection? section;

  @override
  String get location => _withQuery(path, {'tab': ?section?.name});
}

final class MoreRoute extends ShellRoute {
  const MoreRoute();

  static const path = '/more';
  static const name = 'more';

  @override
  String get location => path;
}
