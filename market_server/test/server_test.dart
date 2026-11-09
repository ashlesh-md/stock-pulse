import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:market_server/market_server.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// End-to-end tests over real HTTP and a real WebSocket on a random port.
void main() {
  late MarketServer server;
  late HttpServer http_;
  late Uri base;
  const auth = {'authorization': 'Bearer $demoToken'};

  setUp(() async {
    server = MarketServer(
      engine: MarketEngine(
        instruments,
        random: Random(1),
        intradayDays: 1,
        dailyDays: 60,
      ),
      flushInterval: const Duration(milliseconds: 20),
    );
    http_ = await io.serve(server.handler, InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://localhost:${http_.port}');
  });

  tearDown(() async {
    await server.close();
    await http_.close(force: true);
  });

  Future<Map<String, Object?>> getJson(String path, {int status = 200}) async {
    final res = await http.get(base.resolve(path), headers: auth);
    expect(res.statusCode, status, reason: res.body);
    return jsonDecode(res.body) as Map<String, Object?>;
  }

  group('REST', () {
    test('401 without a token', () async {
      final res = await http.get(base.resolve('/api/v1/instruments'));
      expect(res.statusCode, 401);
      expect(_at(jsonDecode(res.body), ['error', 'code']), 'unauthorized');
    });

    test('instruments, quotes and candles', () async {
      final instruments = await getJson('/api/v1/instruments');
      // S-6: 50 equities + NIFTY (was 12 in v1).
      expect((instruments['data']! as List), hasLength(51));

      final quotes = await getJson('/api/v1/quotes?symbols=TCS,INFY');
      expect(
        [
          for (final q in quotes['data']! as List) _at(q, ['s']),
        ],
        ['TCS', 'INFY'],
      );

      final candles = await getJson(
        '/api/v1/instruments/TCS/candles?interval=5m&limit=5',
      );
      expect(candles['data'], hasLength(5));

      await getJson('/api/v1/instruments/TCS/candles?interval=7m', status: 400);
      await getJson('/api/v1/quotes?symbols=NOPE', status: 404);

      // Daily candles for a window, like a "1M" chart asks for.
      final from = DateTime.now().toUtc().subtract(const Duration(days: 10));
      final daily = await getJson(
        '/api/v1/instruments/TCS/candles?interval=1d&from=${from.millisecondsSinceEpoch}',
      );
      final starts = [
        for (final c in daily['data']! as List) _at(c, ['t'])! as int,
      ];
      expect(starts, isNotEmpty);
      expect(starts.every((t) => t >= from.millisecondsSinceEpoch), isTrue);
      expect(
        (await getJson('/api/v1/instruments/TCS/candles?interval=1w'))['data'],
        isNotEmpty,
      );
    });

    test('place an order with an idempotency key twice → one order', () async {
      Future<http.Response> place() => http.post(
        base.resolve('/api/v1/orders'),
        headers: {
          ...auth,
          'content-type': 'application/json',
          'idempotency-key': 'k1',
        },
        body: jsonEncode({
          'symbol': 'SBIN',
          'side': 'buy',
          'type': 'market',
          'quantity': 2,
        }),
      );
      final a = await place();
      final b = await place();
      expect(a.statusCode, 201);
      expect(
        _at(jsonDecode(a.body), ['data', 'id']),
        _at(jsonDecode(b.body), ['data', 'id']),
      );
      final orders = await getJson('/api/v1/orders');
      expect(orders['data'], hasLength(1));
      final positions = await getJson('/api/v1/positions');
      expect(_at((positions['data']! as List).single, ['quantity']), 2);
    });
  });

  group('WebSocket', () {
    Future<(WebSocketChannel, StreamIterator<Map<String, Object?>>)>
    connect() async {
      final channel = IOWebSocketChannel.connect(
        Uri.parse('ws://localhost:${http_.port}/ws?token=$demoToken'),
      );
      await channel.ready;
      final messages = StreamIterator(
        channel.stream.map(
          (m) => jsonDecode(m as String) as Map<String, Object?>,
        ),
      );
      return (channel, messages);
    }

    Future<Map<String, Object?>> next(
      StreamIterator<Map<String, Object?>> it,
      String type,
    ) async {
      while (await it.moveNext().timeout(const Duration(seconds: 3))) {
        if (it.current['type'] == type) return it.current;
      }
      throw StateError('stream closed before $type');
    }

    test('bad token is refused at the handshake', () async {
      final channel = IOWebSocketChannel.connect(
        Uri.parse('ws://localhost:${http_.port}/ws?token=bad'),
      );
      await expectLater(
        channel.ready,
        throwsA(isA<WebSocketChannelException>()),
      );
    });

    test(
      'welcome → subscribe → ack → snapshot → live ticks with increasing seq',
      () async {
        final (channel, it) = await connect();
        expect((await next(it, 'welcome'))['flushMs'], 20);

        channel.sink.add(
          jsonEncode({
            'op': 'subscribe',
            'id': 1,
            'symbols': ['TCS', 'INFY'],
            'mode': 'ltp',
          }),
        );
        final ack = await next(it, 'ack');
        expect(ack['id'], 1);

        final snapshot = await next(it, 'ticks');
        expect([
          for (final q in snapshot['data']! as List) _at(q, ['s']),
        ], unorderedEquals(['TCS', 'INFY']));
        expect(
          ((snapshot['data']! as List).first as Map<String, Object?>)
              .containsKey('o'),
          isFalse,
          reason: 'ltp mode',
        );

        for (var i = 0; i < 5; i++) {
          server.engine.step();
        }
        final live = await next(it, 'ticks');
        expect(live['seq'] as int, greaterThan(snapshot['seq'] as int));
        await channel.sink.close();
      },
    );

    test('ping → pong echoes the client timestamp', () async {
      final (channel, it) = await connect();
      channel.sink.add(jsonEncode({'op': 'ping', 'ts': 123}));
      expect((await next(it, 'pong'))['ts'], 123);
      await channel.sink.close();
    });

    test('errors for bad input do not close the socket', () async {
      final (channel, it) = await connect();
      channel.sink.add('not json');
      expect((await next(it, 'error'))['code'], 'invalid_message');
      channel.sink.add(
        jsonEncode({
          'op': 'subscribe',
          'id': 7,
          'symbols': ['NOPE'],
        }),
      );
      final err = await next(it, 'error');
      expect(err['code'], 'unknown_symbol');
      expect(err['id'], 7);
      channel.sink.add(jsonEncode({'op': 'ping', 'ts': 1}));
      await next(it, 'pong');
      await channel.sink.close();
    });

    test('order fills are pushed to a socket on the orders channel', () async {
      final (channel, it) = await connect();
      await next(it, 'welcome');
      // v2: order frames need the orders channel (v1 broadcast them).
      channel.sink.add(
        jsonEncode({'op': 'subscribe', 'id': 1, 'channel': 'orders'}),
      );
      await next(it, 'ack');
      server.broker.place(
        symbol: 'ITC',
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 1,
      );
      final order = await next(it, 'order');
      expect((order['data']! as Map)['status'], 'complete');
      await channel.sink.close();
    });

    test(
      'debug drop closes with 4002 so the client knows to reconnect',
      () async {
        final (channel, it) = await connect();
        await next(it, 'welcome');
        await server.gateway.dropAll();
        expect(await it.moveNext(), isFalse);
        expect(channel.closeCode, CloseCodes.reconnectNow);
      },
    );
  });
}

Object? _at(Object? json, List<String> path) {
  var node = json;
  for (final key in path) {
    node = (node! as Map<String, Object?>)[key];
  }
  return node;
}
