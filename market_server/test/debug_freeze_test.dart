import 'package:test/test.dart';

import 'support/protocol_rig.dart';

void main() {
  late ProtocolRig rig;

  setUp(() async => rig = await ProtocolRig.start());
  tearDown(() async => rig.close());

  test('FR-121 S-8 AC1 a frozen id leaves ticks and ka and is listed in ex '
      'while TCS keeps ticking', () async {
    final client = await rig.connect();
    await rig.subscribe(client, ['RELIANCE', 'TCS']);
    rig.server.gateway.freezeId('RELIANCE', const Duration(seconds: 6));
    final from = client.frames.length;
    for (var i = 0; i < 5; i++) {
      rig.tradeAll(['RELIANCE', 'TCS']);
      rig.clock.advance(const Duration(seconds: 1));
      rig.server.gateway
        ..flushNow()
        ..keepAliveNow();
    }
    await client.sync();
    final frames = client.frames.skip(from).where((f) => f.containsKey('seq'));
    final ticks = frames.where((f) => f['type'] == 'ticks').toList();
    expect(ticks, isNotEmpty);
    for (final f in ticks) {
      final ids = (f['data']! as List).map((q) => (q as Map)['s']);
      expect(ids, ['TCS']);
      expect((f['ex']! as Map).keys, ['RELIANCE']);
    }
    for (final f in frames.where((f) => f['type'] == 'ka')) {
      expect(f['quotes'], isNot(contains('RELIANCE')));
      expect((f['ex']! as Map).keys, ['RELIANCE']);
    }
  });

  test('the first frame after a freeze carries the current value', () async {
    final client = await rig.connect();
    await rig.subscribe(client, ['RELIANCE']);
    rig.server.gateway.freezeId('RELIANCE', const Duration(seconds: 2));
    rig.tradeAll(['RELIANCE']);
    rig.server.gateway.flushNow();
    rig.clock.advance(const Duration(seconds: 3));
    final from = client.frames.length;
    rig.server.gateway.flushNow();
    final ticks = await client.type('ticks', from: from);
    final quote = (ticks['data']! as List).single as Map;
    expect(quote['s'], 'RELIANCE');
    expect(quote['ltp'], rig.server.engine['RELIANCE']!.ltp);
    expect(ticks.containsKey('ex'), isFalse);
  });

  test('freezing an underlying freezes its options and its chain', () async {
    final client = await rig.connect();
    final expiry =
        rig.server.options.expiries('NIFTY').first['code']! as String;
    final from = client.frames.length;
    client.send({
      'op': 'subscribe',
      'id': 2,
      'channel': 'chain',
      'underlying': 'NIFTY',
      'expiry': expiry,
      'fromStrike': 1,
      'toStrike': 100000,
    });
    final snapshot = await client.type('chain', from: from);
    final row = (snapshot['rows']! as List).first as Map;
    final contract = (row['ce']! as Map)['contractId']! as String;

    rig.server.gateway.freezeId('NIFTY', const Duration(seconds: 5));
    expect(rig.server.gateway.isIdFrozen(contract), isTrue);
    expect(rig.server.gateway.isIdFrozen('TCS'), isFalse);
    final after = client.frames.length;
    rig.clock.advance(const Duration(seconds: 2));
    rig.server.gateway
      ..flushNow()
      ..keepAliveNow();
    await client.sync();
    final sent = client.frames.skip(after);
    expect(sent.where((f) => f['type'] == 'chain'), isEmpty);
    for (final ka in sent.where((f) => f['type'] == 'ka')) {
      expect(ka['chains'], isEmpty);
    }
  });

  test(
    'a frozen contract is left out of chain deltas and listed in ex',
    () async {
      final client = await rig.connect();
      final expiry =
          rig.server.options.expiries('NIFTY').first['code']! as String;
      final from = client.frames.length;
      client.send({
        'op': 'subscribe',
        'id': 2,
        'channel': 'chain',
        'underlying': 'NIFTY',
        'expiry': expiry,
        'fromStrike': 1,
        'toStrike': 100000,
      });
      final snapshot = await client.type('chain', from: from);
      final row = (snapshot['rows']! as List).first as Map;
      final contract = (row['ce']! as Map)['contractId']! as String;
      rig.server.gateway.freezeId(contract, const Duration(seconds: 30));

      final after = client.frames.length;
      rig.server.engine.step();
      rig.clock.advance(const Duration(seconds: 2));
      rig.server.gateway.flushNow();
      final delta = await client.type('chain', from: after);
      expect((delta['ex']! as Map).keys, [contract]);
      final cells = [
        for (final r in (delta['rows']! as List).cast<Map<String, Object?>>())
          for (final c in r.values.whereType<Map<String, Object?>>())
            c['contractId'],
      ];
      expect(cells, isNot(contains(contract)));
    },
  );
}
