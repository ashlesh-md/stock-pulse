import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/features/options/data/live_chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';

import '../../helpers/fake_market_socket.dart';

void main() {
  test('ka folds a chain by updating asOf and preserving its rows', () async {
    const request = ChainRequest(
      underlying: 'NIFTY',
      expiry: '2026-11-12',
      fromStrike: 25000,
      toStrike: 25000,
    );
    final response = {
      'data': {
        'chainId': request.chainId,
        'seq': 1,
        'asOf': 1000,
        'spot': 25000.0,
        'atm': 25000,
        'status': 'open',
        'strikes': [25000],
        'rows': [
          {
            'strike': 25000,
            'ce': {
              'contractId': 'NIFTY-261112-25000-CE',
              'ltp': 100.0,
              'change': 1.0,
              'oi': 500,
              'oiChange': 10,
              'iv': 18.0,
              'delta': .5,
            },
            'pe': null,
          },
        ],
      },
    };
    final socket = FakeMarketSocket();
    final repository = LiveChainRepository(
      ApiClient(
        const AppConfig(host: 'test'),
        client: MockClient(
          (_) async => http.Response(jsonEncode(response), 200),
        ),
      ),
      socket,
    );
    final values = <ChainView>[];
    final subscription = repository
        .watchChain(request)
        .views
        .listen(values.add);
    await pumpEventQueue();
    expect(values, hasLength(1));
    final before = values.single;

    socket.emit({
      'type': 'ka',
      'asOf': 2000,
      'quotes': <String>[],
      'chains': [request.chainId],
    });
    await pumpEventQueue();

    expect(values, hasLength(2));
    final after = values.last;
    expect(after.asOf, DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true));
    expect(identical(after.rows, before.rows), isTrue);
    expect(after.spot, before.spot);
    expect(after.atm, before.atm);
    expect(after.status, before.status);

    await subscription.cancel();
    await socket.dispose();
  });
}
