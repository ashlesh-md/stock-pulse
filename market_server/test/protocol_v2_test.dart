import 'package:market_server/market_server.dart';
import 'package:test/test.dart';

import 'support/protocol_rig.dart';

void main() {
  late ProtocolRig rig;

  setUp(() async => rig = await ProtocolRig.start());
  tearDown(() => rig.close());

  test(
    'welcome and pong carry serverTime; welcome carries the clock',
    () async {
      final c = await rig.connect();
      final welcome = c.frames.first;
      expect(welcome['serverTime'], rig.clock.wallNow().millisecondsSinceEpoch);
      expect(welcome.containsKey('seq'), isFalse);
      expect(welcome['keepAliveMs'], const Duration(hours: 1).inMilliseconds);
      final clockBody = welcome['clock']! as Map;
      expect(clockBody['phase'], 'open');
      expect(clockBody['mode'], 'real');
      expect(clockBody['tradingDay'], '2026-11-10');
      expect(
        clockBody['marketTime'],
        Ist.at(tue, 10, 0).millisecondsSinceEpoch,
      );
      expect(
        clockBody['nextPhaseAt'],
        Ist.at(tue, 15, 30).millisecondsSinceEpoch,
      );

      rig.clock.advance(const Duration(seconds: 3));
      c.send({'op': 'ping', 'ts': 42});
      final pong = await c.type('pong');
      expect(pong['ts'], 42);
      expect(pong['serverTime'], rig.clock.wallNow().millisecondsSinceEpoch);
      expect(pong.containsKey('seq'), isFalse);
      await c.close();
    },
  );

  test('every data frame has seq +1 and asOf; ack/pong/error have no seq '
      '(AC1)', () async {
    final c = await rig.connect();
    await rig.subscribe(c, ['TCS', 'INFY']);
    c.send({'op': 'subscribe', 'id': 2, 'channel': 'orders'});
    for (var i = 0; i < 4; i++) {
      rig.clock.advance(const Duration(milliseconds: 300));
      rig.tradeAll(['TCS']);
      rig.server.gateway.flushNow();
    }
    rig.clock.advance(const Duration(seconds: 1));
    rig.server.gateway.keepAliveNow();
    await c.sync();
    rig.server.broker.place(
      symbol: 'ITC',
      side: OrderSide.buy,
      type: OrderType.market,
      quantity: 1,
    );
    rig.clock.jumpTo(Ist.at(tue, 11, 0));
    c.send({'op': 'subscribe', 'id': 3, 'channel': 'nope'});
    await c.type('error');
    await c.sync();

    final data = c.data.toList();
    expect(data.map((f) => f['type']).toSet(), {
      'ticks',
      'ka',
      'order',
      // The orders channel is the account channel: a fill also pushes the
      // new position and funds.
      'position',
      'funds',
      'clock',
    });
    for (var i = 0; i < data.length; i++) {
      expect(data[i]['seq'], i + 1, reason: '${data[i]}');
      expect(data[i]['asOf'], isA<int>(), reason: '${data[i]}');
    }
    for (final f in c.frames) {
      if (f['type'] case 'ack' || 'pong' || 'error' || 'welcome') {
        expect(f.containsKey('seq'), isFalse, reason: '$f');
      }
    }
    // asOf is wall time: the market jump did not move it.
    expect(
      data.last['asOf'],
      rig.clock.wallNow().millisecondsSinceEpoch,
      reason: 'clock frame after jumpTo',
    );
    await c.close();
  });

  test('debug subscriptions expose quote ids and unsubscribe counts', () async {
    final c = await rig.connect();
    await rig.subscribe(c, ['TCS', 'INFY']);

    Map<String, Object?> session() {
      final data = rig.server.gateway.subscriptionsJson();
      return (data['sessions']! as List).single as Map<String, Object?>;
    }

    expect(session()['quoteIds'], ['INFY', 'TCS']);
    expect(session()['quoteUnsubscribeCount'], 0);
    final from = c.frames.length;
    c.send({
      'op': 'unsubscribe',
      'id': 2,
      'channel': 'quotes',
      'symbols': ['INFY'],
    });
    await c.waitFor(
      (frame) => frame['type'] == 'ack' && frame['id'] == 2,
      from: from,
    );
    expect(session()['quoteIds'], ['TCS']);
    expect(session()['quoteUnsubscribeCount'], 1);

    await c.close();
  });

  test(
    'unchanged quote is confirmed by ka at most 2 s apart over 10 s (AC2)',
    () async {
      final c = await rig.connect();
      await rig.subscribe(c, ['RELIANCE']);
      final start = c.frames.length;
      for (var i = 0; i < 10; i++) {
        rig.clock.advance(const Duration(seconds: 1));
        rig.server.gateway.keepAliveNow();
        rig.server.gateway.keepAliveNow(); // same instant: no second ka
      }
      await c.sync();

      final confirmations = <int>[
        for (final f in c.frames.skip(start - 1))
          if ((f['type'] == 'ka' &&
                  (f['quotes']! as List).contains('RELIANCE')) ||
              (f['type'] == 'ticks' &&
                  (f['data']! as List).any(
                    (q) => (q as Map)['s'] == 'RELIANCE',
                  )))
            f['asOf']! as int,
      ];
      expect(confirmations, hasLength(11)); // initial ticks + 10 ka
      for (var i = 1; i < confirmations.length; i++) {
        expect(
          confirmations[i] - confirmations[i - 1],
          lessThanOrEqualTo(2000),
        );
      }
      await c.close();
    },
  );

  test('ka skips quotes a ticks frame confirmed within 250 ms', () async {
    final c = await rig.connect();
    await rig.subscribe(c, ['TCS'], throttleMs: 0);
    // INFY is held back by its throttle, so only ka can confirm it.
    await rig.subscribe(c, ['INFY'], throttleMs: 60000);
    rig.clock.advance(const Duration(seconds: 1));
    rig.tradeAll(['TCS']);
    rig.server.gateway.flushNow();
    rig.clock.advance(const Duration(milliseconds: 100));
    rig.server.gateway.keepAliveNow();
    final ka = await c.type('ka');
    expect(ka['quotes'], contains('INFY'));
    expect(ka['quotes'], isNot(contains('TCS')));
    await c.close();
  });

  test('throttleMs holds a quote until it is due', () async {
    final c = await rig.connect();
    await rig.subscribe(c, ['TCS'], throttleMs: 1000);
    final start = c.frames.length;
    rig.clock.advance(const Duration(milliseconds: 300));
    rig.tradeAll(['TCS']);
    rig.server.gateway.flushNow();
    await c.sync();
    expect(c.frames.skip(start).where((f) => f['type'] == 'ticks'), isEmpty);

    rig.clock.advance(const Duration(milliseconds: 700));
    rig.server.gateway.flushNow();
    final ticks = await c.type('ticks', from: start);
    expect(
      ((ticks['data']! as List).single as Map<String, Object?>)['s'],
      'TCS',
    );
    await c.close();
  });
}
