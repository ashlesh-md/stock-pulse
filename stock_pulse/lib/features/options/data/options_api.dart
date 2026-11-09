import 'package:stock_pulse/core/network/domain/endpoint.dart';

Endpoint expiriesEndpoint(String underlying) =>
    Endpoint.get('/api/v1/options/${Uri.encodeComponent(underlying)}/expiries');
Endpoint chainEndpoint(String underlying, String expiry) => Endpoint.get(
  '/api/v1/options/${Uri.encodeComponent(underlying)}/${Uri.encodeComponent(expiry)}',
);
