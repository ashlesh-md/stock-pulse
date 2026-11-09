import 'package:stock_pulse/core/network/domain/endpoint.dart';

const positionsEndpoint = Endpoint.get('/api/v1/positions');
const fundsEndpoint = Endpoint.get('/api/v1/funds');
const holdingsEndpoint = Endpoint.get('/api/v1/holdings');

Endpoint addFundsEndpoint({
  required double amount,
  required String method,
  required String idempotencyKey,
}) => Endpoint.post(
  '/api/v1/funds',
  body: {'amount': amount, 'method': method},
  headers: {'idempotency-key': idempotencyKey},
);
