import 'package:stock_pulse/core/network/domain/endpoint.dart';
import 'package:stock_pulse/features/market/domain/candle.dart';

const instrumentsEndpoint = Endpoint.get('/api/v1/instruments');

Endpoint quotesEndpoint(List<String> ids, {bool full = false}) => Endpoint.get(
  '/api/v1/quotes',
  query: {'symbols': ids.join(','), if (full) 'mode': 'full'},
);

Endpoint candlesEndpoint(
  String id,
  CandleInterval interval, {
  required int limit,
  DateTime? from,
}) => Endpoint.get(
  '/api/v1/instruments/$id/candles',
  query: {
    'interval': interval.apiName,
    'limit': '$limit',
    if (from != null) 'from': '${from.millisecondsSinceEpoch}',
  },
);

Endpoint instrumentEndpoint(String id) =>
    Endpoint.get('/api/v1/instruments/${Uri.encodeComponent(id)}');
