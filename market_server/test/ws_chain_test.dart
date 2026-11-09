import 'dart:convert';

import 'package:test/test.dart';

import 'support/protocol_rig.dart';

void main() {
  late ProtocolRig rig;

  setUp(() async => rig = await ProtocolRig.start());
  tearDown(() async => rig.close());

  Future<({Map<String, Object?> ack, Map<String, Object?> snapshot})>
  subscribeChain(
    Client client,
    String expiry, {
    int id = 1,
    int? fromStrike,
    int? toStrike,
  }) async {
    final from = client.frames.length;
    client.send({
      'op': 'subscribe',
      'id': id,
      'channel': 'chain',
      'underlying': 'NIFTY',
      'expiry': expiry,
      'fromStrike': fromStrike ?? 1,
      'toStrike': toStrike ?? 100000,
    });
    final ack = await client.type('ack', from: from);
    final snapshot = await client.type('chain', from: from);
    return (ack: ack, snapshot: snapshot);
  }

  test(
    'chain subscribe acks before a snapshot containing only its range',
    () async {
      final client = await rig.connect();
      final expiry =
          rig.server.options.expiries('NIFTY').first['code']! as String;
      final full = rig.server.options.chain('NIFTY', expiry);
      final strikes = (full['strikes']! as List).cast<int>();
      final from = strikes[8];
      final to = strikes[12];

      final result = await subscribeChain(
        client,
        expiry,
        fromStrike: from,
        toStrike: to,
      );

      expect(result.ack['channel'], 'chain');
      expect(result.ack['chainId'], 'NIFTY:$expiry');
      expect(
        client.frames.indexOf(result.ack),
        lessThan(client.frames.indexOf(result.snapshot)),
      );
      expect(result.snapshot['kind'], 'snapshot');
      final rows = (result.snapshot['rows']! as List)
          .cast<Map<String, Object?>>();
      expect(rows, hasLength(5));
      expect(rows.map((row) => row['strike']), [
        from,
        strikes[9],
        strikes[10],
        strikes[11],
        to,
      ]);
      await client.close();
    },
  );

  test(
    'chain deltas contain changed rows and are limited to one per second',
    () async {
      final client = await rig.connect();
      final expiry =
          rig.server.options.expiries('NIFTY').first['code']! as String;
      await subscribeChain(client, expiry);

      // Freeze trading while keeping market time fixed, so only the edited
      // option cell changes and the delta can prove row-level filtering.
      rig.clock.jumpTo(rig.clock.marketNow().add(const Duration(hours: 6)));
      final marketTime = rig.clock.marketNow();
      final baseline = await subscribeChain(client, expiry, id: 2);
      final chainId = baseline.snapshot['chainId']! as String;
      final originalRows = (baseline.snapshot['rows']! as List)
          .cast<Map<String, Object?>>();
      final before = {
        for (final row in originalRows) row['strike']! as int: jsonEncode(row),
      };
      final row = originalRows.first;
      final contractId = (row['ce']! as Map)['contractId']! as String;
      final changedStrike = row['strike'];
      rig.server.engine[contractId]!.ltp += .05;

      rig.clock.advance(const Duration(seconds: 1));
      rig.clock.jumpTo(marketTime);
      final changed = rig.server.options.chain('NIFTY', expiry);
      final expectedStrikes = [
        for (final row
            in (changed['rows']! as List).cast<Map<String, Object?>>())
          if (before[row['strike']! as int] != jsonEncode(row)) row['strike'],
      ];
      final from = client.frames.length;
      rig.server.gateway.flushNow();
      final delta = await client.type('chain', from: from);

      expect(delta['kind'], 'delta');
      expect(delta['chainId'], chainId);
      final deltaRows = (delta['rows']! as List).cast<Map<String, Object?>>();
      expect(deltaRows, isNotEmpty);
      expect(deltaRows.length, lessThan(originalRows.length));
      expect(expectedStrikes, [changedStrike]);
      expect(deltaRows.map((row) => row['strike']), expectedStrikes);

      rig.server.engine[contractId]!.ltp += .05;
      rig.clock.advance(const Duration(milliseconds: 500));
      rig.clock.jumpTo(marketTime);
      final throttledAt = client.frames.length;
      rig.server.gateway.flushNow();
      await client.sync();
      expect(
        client.frames
            .skip(throttledAt)
            .where((frame) => frame['type'] == 'chain'),
        isEmpty,
      );

      rig.server.engine[contractId]!.ltp += .05;
      rig.clock.advance(const Duration(milliseconds: 500));
      rig.clock.jumpTo(marketTime);
      final allowedAt = client.frames.length;
      rig.server.gateway.flushNow();
      final next = await client.type('chain', from: allowedAt);
      expect(next['kind'], 'delta');
      expect(
        (next['asOf']! as int) - (delta['asOf']! as int),
        greaterThanOrEqualTo(1000),
      );
      await client.close();
    },
  );

  test(
    'a keep-alive confirms chain ids without replacing their rows',
    () async {
      final client = await rig.connect();
      final expiry =
          rig.server.options.expiries('NIFTY').first['code']! as String;
      final initial = await subscribeChain(client, expiry);
      final from = client.frames.length;

      rig.clock.advance(const Duration(seconds: 1));
      rig.server.gateway.keepAliveNow();
      final keepAlive = await client.type('ka', from: from);

      expect(keepAlive['chains'], contains('NIFTY:$expiry'));
      expect(keepAlive.containsKey('rows'), isFalse);
      expect(
        client.frames.skip(from).where((frame) => frame['type'] == 'chain'),
        isEmpty,
      );
      expect(initial.snapshot['rows'], hasLength(41));
      await client.close();
    },
  );

  test('a session cannot subscribe to a third chain', () async {
    final client = await rig.connect();
    final expiries = rig.server.options
        .expiries('NIFTY')
        .map((item) => item['code']! as String)
        .take(3)
        .toList();
    expect(expiries, hasLength(3));

    for (var index = 0; index < expiries.length; index++) {
      final from = client.frames.length;
      client.send({
        'op': 'subscribe',
        'id': index + 1,
        'channel': 'chain',
        'underlying': 'NIFTY',
        'expiry': expiries[index],
        'fromStrike': 24000,
        'toStrike': 25000,
      });
      final response = await client.type(
        index < 2 ? 'ack' : 'error',
        from: from,
      );
      if (index < 2) {
        expect(response['channel'], 'chain');
        await client.type('chain', from: from);
      } else {
        expect(response['code'], 'too_many_chains');
      }
    }
    await client.close();
  });
}
