part of 'app_route.dart';

/// A deliberately limited external trade link. It resolves to the ordinary
/// ticket route, where the user still reviews the order and confirms it.
final class TradeRoute extends AppRoute {
  const TradeRoute(this.args);

  final OrderTicketArgs args;

  static TradeRoute? fromQuery(String id, Map<String, String> query) {
    final side = switch (query['side']) {
      'buy' => OrderSide.buy,
      'sell' => OrderSide.sell,
      _ => null,
    };
    final type = query['type'] ?? 'market';
    if (side == null || (type != 'market' && type != 'limit')) return null;
    final price = switch (double.tryParse(query['price'] ?? '')) {
      final double value when value.isFinite && value > 0 => value,
      _ => null,
    };
    if (type == 'limit' && price == null) return null;
    if (type == 'market' && query.containsKey('price')) return null;
    return TradeRoute(
      OrderTicketArgs(
        instrumentId: id,
        side: side,
        limitPrice: price,
        source: OrderSource.deeplink,
      ),
    );
  }

  @override
  String get location => OrderTicketRoute(args).location;
}

final class StockRoute extends AppRoute {
  const StockRoute(this.instrumentId);

  factory StockRoute.fromState(GoRouterState state) =>
      StockRoute(state.pathParameters['id']!);

  static const path = '/stock/:id';
  static const name = 'stockDetail';

  final String instrumentId;

  @override
  String get location => '/stock/${Uri.encodeComponent(instrumentId)}';
}

/// The builder reads its legs from the strategy draft controller, which the
/// caller loads before pushing.
final class StrategyRoute extends AppRoute {
  const StrategyRoute();

  static const path = '/strategy';
  static const name = 'strategy';

  @override
  String get location => path;
}

/// Developer screen; no `ScreenId`, so it hides every screen under it.
final class SocketLabRoute extends AppRoute {
  const SocketLabRoute();

  static const path = '/more/socket-lab';
  static const name = 'socketLab';

  @override
  String get location => path;
}

final class AddFundsRoute extends AppRoute {
  const AddFundsRoute();
  static const path = '/more/add-funds';
  static const name = 'addFunds';
  @override
  String get location => path;
}

final class OrderTicketRoute extends AppRoute {
  const OrderTicketRoute(this.args);
  static const path = '/order/:id';
  static const name = 'orderTicket';
  final OrderTicketArgs args;
  factory OrderTicketRoute.fromState(GoRouterState state) =>
      OrderTicketRoute.fromQuery(
        state.pathParameters['id']!,
        state.uri.queryParameters,
      );
  factory OrderTicketRoute.fromQuery(String id, Map<String, String> query) =>
      OrderTicketRoute(
        OrderTicketArgs(
          instrumentId: id,
          side: OrderSide.values.asNameMap()[query['side']] ?? OrderSide.buy,
          lots: switch (int.tryParse(query['lots'] ?? '')) {
            final int n when n > 0 => n,
            _ => null,
          },
          product: ProductType.values.asNameMap()[query['product']],
          limitPrice: switch (double.tryParse(query['price'] ?? '')) {
            final double n when n.isFinite && n > 0 => n,
            _ => null,
          },
          source:
              OrderSource.values.asNameMap()[query['source']] ??
              OrderSource.manual,
        ),
      );
  @override
  String get location =>
      _withQuery('/order/${Uri.encodeComponent(args.instrumentId)}', {
        'side': args.side.name,
        'lots': ?args.lots?.toString(),
        'product': ?args.product?.name,
        'price': ?args.limitPrice?.toString(),
        if (args.source != OrderSource.manual) 'source': args.source.name,
      });
}

final class DebugClockRoute extends AppRoute {
  const DebugClockRoute();
  static const path = '/more/clock';
  static const name = 'debugClock';
  @override
  String get location => path;
}

final class AlertsRoute extends AppRoute {
  const AlertsRoute();
  static const path = '/alerts';
  static const name = 'alerts';
  @override
  String get location => path;
}
