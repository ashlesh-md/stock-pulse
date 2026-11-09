import 'package:stock_pulse/core/network/domain/endpoint.dart';

const ordersEndpoint = Endpoint.get('/api/v1/orders');

Endpoint orderEndpoint(String id) => Endpoint.get('/api/v1/orders/$id');

Endpoint cancelOrderEndpoint(String id) =>
    Endpoint.delete('/api/v1/orders/$id');

/// The server returns the first order again for a repeated
/// [idempotencyKey], so a retry never places twice.
Endpoint placeOrderEndpoint(
  Map<String, Object?> body, {
  required String idempotencyKey,
}) => Endpoint.post(
  '/api/v1/orders',
  body: body,
  headers: {'idempotency-key': idempotencyKey},
);

Endpoint orderByKeyEndpoint(String key) =>
    Endpoint.get('/api/v1/orders', query: {'key': key});
