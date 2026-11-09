import 'dart:io';
import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

import 'support/protocol_rig.dart';

void main() {
  late ProtocolRig rig;

  setUp(() async => rig = await ProtocolRig.start());
  tearDown(() => rig.close());

  Future<Map<String, Object?>> request(
    Client c,
    Map<String, Object?> op, {
    String type = 'ack',
  }) {
    final from = c.frames.length;
    c.send(op);
    return c.type(type, from: from);
  }

  test('unsubscribe acks and stops the quotes', () async {
    final c = await rig.connect();
    await rig.subscribe(c, ['TCS']);
    final ack = await request(c, {
      'op': 'unsubscribe',
      'id': 2,
      'symbols': ['TCS'],
    });
    expect(ack, containsPair('op', 'unsubscribe'));
    expect(ack['symbols'], ['TCS']);

    final from = c.frames.length;
    rig.tradeAll(['TCS']);
    rig.server.gateway.flushNow();
    await c.sync();
    expect(c.frames.skip(from).where((f) => f['type'] == 'ticks'), isEmpty);
  });

  test('subscribing again replaces the mode', () async {
    final c = await rig.connect();
    await rig.subscribe(c, ['TCS']);
    final from = c.frames.length;
    c.send({
      'op': 'subscribe',
      'id': 3,
      'symbols': ['TCS'],
      'mode': 'full',
    });
    final ticks = await c.type('ticks', from: from);
    final quote = (ticks['data']! as List).single as Map;
    expect(quote.containsKey('depth'), isTrue);
  });

  test('an unknown mode is an invalid_mode error', () async {
    final c = await rig.connect();
    final error = await request(c, {
      'op': 'subscribe',
      'id': 4,
      'symbols': ['TCS'],
      'mode': 'huge',
    }, type: 'error');
    expect(error, containsPair('code', 'invalid_mode'));
    expect(error, containsPair('id', 4));
  });

  test('an unknown op is an unknown_op error', () async {
    final c = await rig.connect();
    final error = await request(c, {'op': 'dance', 'id': 5}, type: 'error');
    expect(error, containsPair('code', 'unknown_op'));
  });

  test('freeze silences a session until the time passes', () async {
    final c = await rig.connect();
    await rig.subscribe(c, ['TCS']);
    rig.server.gateway.freezeAll(const Duration(seconds: 2));
    final from = c.frames.length;
    c.send({'op': 'ping', 'ts': 1});
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(c.frames.skip(from), isEmpty);

    rig.clock.advance(const Duration(seconds: 3));
    await c.sync();
  });

  test('the idle check closes a session that sent nothing', () async {
    final c = await rig.connect();
    rig.clock.advance(const Duration(seconds: 31));
    rig.server.gateway.idleCheckNow();
    await c.channel.sink.done;
    expect(c.channel.closeCode, 4000);
    expect(rig.server.gateway.connectionCount, 0);
  });

  test('more quote ids than the cap is too_many_subscriptions', () async {
    final clock = FakeMarketClock(
      wallStart: DateTime.utc(2026, 11),
      marketStart: DateTime.utc(2026, 11, 10, 5),
    );
    final engine = MarketEngine(
      instruments,
      random: Random(1),
      clock: clock.marketNow,
      intradayDays: 0,
      dailyDays: 0,
    );
    final gateway = WsGateway(
      engine,
      Broker(engine),
      clock: clock,
      calendar: MarketCalendar(holidays: const {}, holidaySourceDate: 't'),
      maxQuotes: 2,
    );
    final http = await io.serve(
      gateway.handler,
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() async {
      await gateway.close();
      await http.close(force: true);
    });
    final channel = IOWebSocketChannel.connect(
      Uri.parse('ws://localhost:${http.port}/?token=$demoToken'),
    );
    final c = Client(channel);
    await c.type('welcome');
    final error = await request(c, {
      'op': 'subscribe',
      'id': 6,
      'symbols': ['TCS', 'INFY', 'ITC'],
    }, type: 'error');
    expect(error, containsPair('code', 'too_many_subscriptions'));
  });
}
