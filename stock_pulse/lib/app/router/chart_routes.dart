part of 'app_route.dart';

final class ChartRoute extends AppRoute {
  const ChartRoute(this.instrumentId, {this.selection});
  factory ChartRoute.fromState(GoRouterState state) => ChartRoute.fromQuery(
    state.pathParameters['id']!,
    state.uri.queryParameters,
  );
  factory ChartRoute.fromQuery(String id, Map<String, String> query) =>
      ChartRoute(
        id,
        selection:
            query.containsKey('range') ||
                query.containsKey('interval') ||
                query.containsKey('type')
            ? ChartSelection.fromQuery(query)
            : null,
      );
  static const path = 'chart';
  static const name = 'chartFullscreen';
  final String instrumentId;
  final ChartSelection? selection;
  @override
  String get location =>
      _withQuery('/stock/${Uri.encodeComponent(instrumentId)}/chart', {
        'range': ?selection?.range.label,
        'interval': ?selection?.interval.apiName,
        'type': ?selection?.type?.name,
      });
}
