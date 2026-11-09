import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:market_server/market_server.dart';
import 'package:test/test.dart';

import 'support/protocol_rig.dart';

void main() {
  late ProtocolRig rig;

  setUp(() async => rig = await ProtocolRig.start());
  tearDown(() => rig.close());

  test(
    'skip-seq → client resync → ticks snapshot then resync ack (AC3)',
    () async {
      final c = await rig.connect();
      await rig.subscribe(c, ['TCS', 'INFY', 'NIFTY']);
      final lastSeq = c.data.last['seq']! as int;
      rig.server.gateway.skipSequence();
      rig.clock.advance(const Duration(seconds: 1));
      rig.tradeAll(['TCS']);
      rig.server.gateway.flushNow();
      final gap = await c.waitFor((f) => (f['seq'] as int? ?? 0) > lastSeq);
      expect(gap['seq'], lastSeq + 2);

      final from = c.frames.length;
      c.send({'op': 'resync', 'id': 7});
      final ack = await c.waitFor((f) => f['op'] == 'resync', from: from);
      final after = c.frames.sublist(from);
      final snapshot = after.first;
      expect(snapshot['type'], 'ticks');
      expect(snapshot['kind'], 'snapshot');
      expect([
        for (final q in snapshot['data']! as List) (q as Map)['s'],
      ], unorderedEquals(['TCS', 'INFY', 'NIFTY']));
      expect(after.indexOf(ack), greaterThan(after.indexOf(snapshot)));
      expect(ack['type'], 'ack');
      expect(ack['id'], 7);
      expect(ack['seq'], snapshot['seq']);
      await c.close();
    },
  );

  test(
    'order frames reach only the session on the orders channel (AC4)',
    () async {
      final a = await rig.connect();
      final b = await rig.connect();
      a.send({'op': 'subscribe', 'id': 1, 'channel': 'orders'});
      final ack = await a.type('ack');
      expect(ack['channel'], 'orders');
      b.send({'op': 'subscribe', 'id': 1, 'channel': 'alerts'});
      await b.type('ack');

      rig.server.broker.place(
        symbol: 'ITC',
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 1,
      );
      final order = await a.type('order');
      expect((order['data']! as Map)['symbol'], 'ITC');
      expect(order['asOf'], isA<int>());
      await b.sync();
      expect(b.frames.where((f) => f['type'] == 'order'), isEmpty);

      a.send({'op': 'unsubscribe', 'id': 2, 'channel': 'orders'});
      await a.waitFor((f) => f['op'] == 'unsubscribe');
      final from = a.frames.length;
      rig.server.broker.place(
        symbol: 'ITC',
        side: OrderSide.buy,
        type: OrderType.market,
        quantity: 1,
      );
      await a.sync();
      expect(a.frames.skip(from).where((f) => f['type'] == 'order'), isEmpty);
      await a.close();
      await b.close();
    },
  );

  test('alert crossing emits one identified trigger frame', () async {
    final client = await rig.connect();
    client.send({'op': 'subscribe', 'id': 1, 'channel': 'alerts'});
    await client.type('ack');

    final stock = rig.server.engine['TCS']!;
    final tick = stock.instrument.tickSize;
    final level = ((stock.ltp + 1) / tick).ceil() * tick;
    final created = rig.server.account.createAlert('TCS', 'above', level);
    final active = await client.type('alert');
    expect((active['data']! as Map)['status'], 'active');

    final from = client.frames.length;
    stock.ltp = level + tick;
    rig.server.account.evaluateAlerts();
    final triggered = await client.type('alert', from: from);
    final data = triggered['data']! as Map<String, Object?>;
    expect(data['alertId'], created['alertId']);
    expect(data['status'], 'triggered');
    expect(DateTime.tryParse(data['triggeredAt']! as String), isNotNull);

    rig.server.account.evaluateAlerts();
    await client.sync();
    expect(
      client.data
          .where(
            (frame) =>
                frame['type'] == 'alert' &&
                (frame['data']! as Map)['status'] == 'triggered',
          )
          .length,
      1,
    );
    await client.close();
  });

  test('a clock jump sends a clock frame with the new market time', () async {
    final c = await rig.connect();
    rig.clock.jumpTo(Ist.at(tue, 16, 0));
    final frame = await c.waitFor(
      (f) => f['type'] == 'clock' && f['phase'] == 'closed',
    );
    expect(frame['marketTime'], Ist.at(tue, 16, 0).millisecondsSinceEpoch);
    expect(frame['overridden'], isTrue);
    expect(frame['serverTime'], rig.clock.wallNow().millisecondsSinceEpoch);
    await c.close();
  });

  test(
    'channel errors: unknown channel, invalid chain request, bad throttle',
    () async {
      final c = await rig.connect();
      c.send({'op': 'subscribe', 'id': 1, 'channel': 'news'});
      expect((await c.type('error'))['code'], 'unknown_channel');
      var from = c.frames.length;
      c.send({'op': 'subscribe', 'id': 2, 'channel': 'chain'});
      expect((await c.type('error', from: from))['code'], 'invalid_chain');
      from = c.frames.length;
      c.send({
        'op': 'subscribe',
        'id': 3,
        'symbols': ['TCS'],
        'throttleMs': 'fast',
      });
      expect((await c.type('error', from: from))['id'], 3);
      from = c.frames.length;
      c.send({
        'op': 'subscribe',
        'id': 4,
        'symbols': ['TCS'],
      });
      final ack = await c.type('ack', from: from);
      expect(ack['channel'], 'quotes', reason: 'channel defaults to quotes');
      expect(ack['throttleMs'], 250);
      await c.close();
    },
  );

  test('REST /clock and /quotes asOf use the same clocks', () async {
    const auth = {'authorization': 'Bearer $demoToken'};
    final base = Uri.parse('http://localhost:${rig.http.port}');
    final c =
        jsonDecode(
              (await http.get(
                base.resolve('/api/v1/clock'),
                headers: auth,
              )).body,
            )
            as Map;
    expect(c['phase'], 'open');
    expect(c['marketOffsetMs'], rig.clock.marketOffset.inMilliseconds);
    final q =
        jsonDecode(
              (await http.get(
                base.resolve('/api/v1/quotes?symbols=TCS'),
                headers: auth,
              )).body,
            )
            as Map;
    expect(q['asOf'], rig.clock.wallNow().millisecondsSinceEpoch);
    expect(q['data'], hasLength(1));
  });
}
