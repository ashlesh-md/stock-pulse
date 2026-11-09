import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/features/more/data/debug_api.dart';
import 'package:stock_pulse/features/more/data/funds_transfer_api.dart';
import 'package:stock_pulse/features/more/domain/chaos.dart';
import 'package:stock_pulse/features/more/domain/payment_method.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';

void main() {
  late List<http.Request> sent;
  late http.Response Function() reply;

  ApiClient client() => ApiClient(
    const AppConfig(host: 'localhost'),
    client: MockClient((r) async {
      sent.add(r);
      return reply();
    }),
  );

  setUp(() {
    sent = [];
    reply = () => http.Response('{}', 200);
  });

  group('DebugChaosTrigger', () {
    test('posts the chaos path and maps success', () async {
      final result = await DebugChaosTrigger(client()).trigger(Chaos.freeze);
      expect(result, isA<Success<void>>());
      expect(sent.single.method, 'POST');
      expect(sent.single.url.path, '/debug/freeze');
    });

    test('passes a server refusal through', () async {
      reply = () => http.Response('{}', 403);
      final result = await DebugChaosTrigger(client()).trigger(Chaos.drop);
      expect(result, isA<Failure<void>>());
    });
  });

  group('FundsTransferApi', () {
    test('sends amount, wire method name and the idempotency key', () async {
      reply = () => http.Response(
        jsonEncode({
          'data': {'available': 6000, 'version': 3},
        }),
        200,
      );
      final result = await FundsTransferApi(client()).submit(
        amount: 5000,
        method: PaymentMethod.netBanking,
        idempotencyKey: 'k1',
      );
      final funds = (result as Success<Funds>).value;
      expect(funds.available, 6000);
      final request = sent.single;
      expect(request.url.path, '/api/v1/funds');
      expect(request.headers['idempotency-key'], 'k1');
      expect(jsonDecode(request.body), {
        'amount': 5000.0,
        'method': 'netBanking',
      });
    });

    test('wire names match the server', () {
      expect(PaymentMethod.values.map(FundsTransferApi.wireName), [
        'upi',
        'netBanking',
      ]);
    });

    test('a server error stays a failure', () async {
      reply = () => http.Response('{}', 500);
      final result = await FundsTransferApi(client())
          .submit(amount: 1, method: PaymentMethod.upi, idempotencyKey: 'k');
      expect(result, isA<Failure<Object?>>());
    });
  });
}
