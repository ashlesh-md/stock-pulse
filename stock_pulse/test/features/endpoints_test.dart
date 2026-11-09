import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/domain/endpoint.dart';
import 'package:stock_pulse/features/more/data/debug_api.dart';
import 'package:stock_pulse/features/more/domain/chaos.dart';
import 'package:stock_pulse/features/portfolio/data/portfolio_api.dart';

void main() {
  test('positions are read with GET /api/v1/positions', () {
    expect(positionsEndpoint.method, HttpMethod.get);
    expect(positionsEndpoint.path, '/api/v1/positions');
  });

  test('each chaos button posts to its own debug endpoint', () {
    expect(
      {for (final c in Chaos.values) c: chaosEndpoint(c).toString()},
      {
        Chaos.drop: 'POST /debug/drop-connections',
        Chaos.freeze: 'POST /debug/freeze',
        Chaos.skipSeq: 'POST /debug/skip-seq',
      },
    );
  });

  test('add funds posts the amount and method with an idempotency key', () {
    final e = addFundsEndpoint(
      amount: 500,
      method: 'upi',
      idempotencyKey: 'k1',
    );
    expect(e.toString(), 'POST /api/v1/funds');
    expect(e.body, {'amount': 500.0, 'method': 'upi'});
    expect(e.headers, {'idempotency-key': 'k1'});
    expect(fundsEndpoint.toString(), 'GET /api/v1/funds');
    expect(holdingsEndpoint.toString(), 'GET /api/v1/holdings');
  });

  test('endpoints are equal by value, including body, query and headers', () {
    Endpoint funds(String key) =>
        addFundsEndpoint(amount: 1, method: 'upi', idempotencyKey: key);
    expect(funds('a'), funds('a'));
    expect(funds('a').hashCode, funds('a').hashCode);
    expect(funds('a'), isNot(funds('b')));
    expect(
      const Endpoint.get('/x', query: {'a': '1'}),
      isNot(const Endpoint.get('/x', query: {'a': '2'})),
    );
    expect(const Endpoint.delete('/x'), isNot(const Endpoint.get('/x')));
    expect(const Endpoint.get('/x'), isNot(const Endpoint.get('/y')));
    expect(funds('a'), isNot(Object()));
  });
}
