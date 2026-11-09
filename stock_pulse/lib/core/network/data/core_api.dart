import 'package:stock_pulse/core/network/domain/endpoint.dart';

const healthEndpoint = Endpoint.get('/health');

Endpoint setClockEndpoint(DateTime marketTime) => Endpoint.post(
  '/debug/clock',
  body: {'time': marketTime.toUtc().toIso8601String()},
);

Endpoint resetEndpoint({DateTime? marketTime}) => Endpoint.post(
  '/debug/reset',
  body: {'time': ?marketTime?.toUtc().toIso8601String()},
);
