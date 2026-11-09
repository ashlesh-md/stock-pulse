import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:market_server/market_server.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A real server on a loopback port with a [FakeMarketClock]. Timers are
/// parked at one hour, so only flushNow / keepAliveNow send.
final cal = MarketCalendar(holidays: const {}, holidaySourceDate: 'test');
const tue = IstDate(2026, 11, 10);

class Client {
  Client(this.channel) {
    channel.stream.listen((raw) {
      frames.add(jsonDecode(raw as String) as Map<String, Object?>);
    });
  }

  final WebSocketChannel channel;
  final frames = <Map<String, Object?>>[];

  void send(Map<String, Object?> op) => channel.sink.add(jsonEncode(op));

  /// Waits for the first frame after [from] matching [test].
  Future<Map<String, Object?>> waitFor(
    bool Function(Map<String, Object?> f) test, {
    int from = 0,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (true) {
      for (var i = from; i < frames.length; i++) {
        if (test(frames[i])) return frames[i];
      }
      final left = deadline.difference(DateTime.now());
      if (left.isNegative) throw StateError('frame not received');
      // Poll: a frame can land between the scan and a stream listen.
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  Future<Map<String, Object?>> type(String t, {int from = 0}) =>
      waitFor((f) => f['type'] == t, from: from);

  /// ping/pong round trip: everything the server sent before the pong has
  /// arrived once this completes.
  Future<void> sync() async {
    final from = frames.length;
    final ts = DateTime.now().microsecondsSinceEpoch;
    send({'op': 'ping', 'ts': ts});
    await waitFor((f) => f['type'] == 'pong' && f['ts'] == ts, from: from);
  }

  Iterable<Map<String, Object?>> get data =>
      frames.where((f) => f.containsKey('seq'));

  Future<void> close() => channel.sink.close();
}

class ProtocolRig {
  ProtocolRig._(this.clock, this.server, this.http);

  static Future<ProtocolRig> start() async {
    final clock = FakeMarketClock(
      wallStart: DateTime.utc(2026, 11, 1, 6),
      marketStart: Ist.at(tue, 10, 0),
    );
    final server = MarketServer(
      clock: clock,
      calendar: cal,
      engine: MarketEngine(
        instruments,
        random: Random(5),
        marketClock: clock,
        calendar: cal,
        intradayDays: 1,
        dailyDays: 10,
      ),
      flushInterval: const Duration(hours: 1),
      keepAliveInterval: const Duration(hours: 1),
    );
    final http = await io.serve(
      server.handler,
      InternetAddress.loopbackIPv4,
      0,
    );
    return ProtocolRig._(clock, server, http);
  }

  final FakeMarketClock clock;
  final MarketServer server;
  final HttpServer http;

  Future<void> close() async {
    await server.close();
    await http.close(force: true);
  }

  Future<Client> connect() async {
    final channel = IOWebSocketChannel.connect(
      Uri.parse('ws://localhost:${http.port}/ws?token=$demoToken'),
    );
    await channel.ready;
    final c = Client(channel);
    await c.type('welcome');
    return c;
  }

  Future<void> subscribe(Client c, List<String> ids, {int? throttleMs}) async {
    final from = c.frames.length;
    c.send({
      'op': 'subscribe',
      'id': 1,
      'channel': 'quotes',
      'symbols': ids,
      'mode': 'ltp',
      'throttleMs': ?throttleMs,
    });
    await c.type('ack', from: from);
    await c.type('ticks', from: from);
  }

  /// Steps until every id traded at least once.
  void tradeAll(List<String> ids) {
    final want = ids.toSet();
    final sub = server.engine.ticks.listen(want.removeAll);
    while (want.isNotEmpty) {
      server.engine.step();
    }
    unawaited(sub.cancel());
  }
}
