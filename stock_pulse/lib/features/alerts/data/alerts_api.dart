import 'package:stock_pulse/core/network/domain/endpoint.dart';

const alertsEndpoint = Endpoint.get('/api/v1/alerts');
Endpoint createAlertEndpoint(String symbol, String condition, double level) =>
    Endpoint.post(
      '/api/v1/alerts',
      body: {'symbol': symbol, 'cond': condition, 'level': level},
    );
Endpoint deleteAlertEndpoint(String id) =>
    Endpoint.delete('/api/v1/alerts/${Uri.encodeComponent(id)}');
