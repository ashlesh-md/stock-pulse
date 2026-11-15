import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/features/options/data/live_chain_repository.dart';
import 'package:stock_pulse/features/options/domain/chain_view.dart';
import 'package:stock_pulse/features/orders/data/live_order_repository.dart';

import '../../helpers/fake_market_socket.dart';

const _request = ChainRequest(
  underlying: 'NIFTY',
  expiry: '2026-11-12',
  fromStrike: 25000,
  toStrike: 25000,
);

final _chainBody = {
  'data': {
    'chainId': _request.chainId,
    'seq': 1,
    'asOf': 1000,
    'spot': 25000.0,
    'atm': 25000,
    'status': 'open',
    'strikes': [25000],
    'rows': <Object?>[],
  },
};

Map<String, Object?> _order() => {
  'id': 'ORD1',
  'clientKey': 'k1',
  'version': 1,
  'symbol': 'TCS',
  'product': 'cnc',
  'side': 'buy',
  'type': 'market',
  'quantity': 2,
  'status': 'open',
  'createdAt': '2026-11-10T04:00:00.000Z',
  'updatedAt': '2026-11-10T04:00:01.000Z',
};

ApiClient _api(Object body) {
  final api = ApiClient(
    const AppConfig(host: 'test'),
    client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
    wait: (_) async {},
  );
  addTearDown(api.close);
  return api;
}

void main() {
  group('F6 a bad order list body', () {
    final cases = <String, Map<String, Object?> Function()>{
      'missing field': () => _order()..remove('symbol'),
      'wrong type': () => _order()..['quantity'] = 'two',
      'unknown enum': () => _order()..['status'] = 'teleported',
    };
    for (final MapEntry(key: name, value: bad) in cases.entries) {
      test('with a $name is a ParseError, never a throw', () async {
        final socket = FakeMarketSocket();
        addTearDown(socket.dispose);
        final repo = LiveOrderRepository(
          _api({
            'data': [_order(), bad()],
          }),
          socket,
        );

        final result = await repo.getOrders();

        expect(
          result,
          isA<Failure<Object?>>().having(
            (f) => f.error,
            'e',
            isA<ParseError>(),
          ),
        );
      });
    }
  });

  group('F6 a bad chain socket frame', () {
    for (final MapEntry(key: name, value: frame) in {
      'ka with a text asOf': {
        'type': 'ka',
        'asOf': 'soon',
        'chains': [_request.chainId],
      },
      'ka with a chains map': {
        'type': 'ka',
        'asOf': 2000,
        'chains': {'id': _request.chainId},
      },
      'chain with a text seq': {
        'type': 'chain',
        'chainId': _request.chainId,
        'seq': 'x',
      },
    }.entries) {
      test('($name) is dropped and the chain stays on screen', () async {
        final socket = FakeMarketSocket();
        addTearDown(socket.dispose);
        final repo = LiveChainRepository(_api(_chainBody), socket);
        final views = <ChainView>[];
        final errors = <Object>[];
        final sub = repo
            .watchChain(_request)
            .views
            .listen(views.add, onError: errors.add);
        addTearDown(sub.cancel);
        await pumpEventQueue();

        socket.emit(frame);
        socket.emit({
          'type': 'ka',
          'asOf': 3000,
          'chains': [_request.chainId],
        });
        await pumpEventQueue();

        expect(errors, isEmpty);
        expect(
          views.last.asOf,
          DateTime.fromMillisecondsSinceEpoch(3000, isUtc: true),
        );
      });
    }
  });
}
