import 'package:stock_pulse/core/network/domain/endpoint.dart';

Endpoint aiAskEndpoint(Map<String, Object?> body) =>
    Endpoint.post('/api/v1/ai/ask', body: body);
