import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/data/socket_config.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';

import '../helpers/test_server.dart';

/// MarketSocket against the real server: subscriptions, reconnect,
/// heartbeat and sequence gaps.
void main() {
  late TestServer server;
  late MarketSocket socket;
  late List<Map<String, Object?>> sent;
  late List<Map<String, Object?>> messages;
  late List<SocketStatus> statuses;
  late int resyncs;

  setUp(() async {
    server = await TestServer.start();
    socket = MarketSocket(
      server.config.socketUri,
      config: const SocketConfig(
        pingInterval: Duration(milliseconds: 100),
        staleAfter: Duration(milliseconds: 400),
        maxBackoff: Duration(milliseconds: 200),
      ),
    );
    sent = [];
    messages = [];
    statuses = [];
    resyncs = 0;
    socket.frames
        .where((f) => f.outgoing)
        .listen((f) => sent.add(jsonDecode(f.text) as Map<String, Object?>));
    socket.messages.listen(messages.add);
    socket.statusChanges.listen(statuses.add);
    socket.resyncNeeded.listen((_) => resyncs++);
    socket.start();
    await eventually(() => socket.status is SocketConnected);
  });

  tearDown(() async {
    await socket.dispose();
    await server.close();
  });

  List<Map<String, Object?>> ops(String op) => [
    for (final m in sent)
      if (m['op'] == op) m,
  ];

  test('subscribe sends one request, then live ticks arrive', () async {
    final sub = socket.subscribeQuotes(['TCS', 'INFY'], FeedMode.ltp);
    await eventually(() => messages.any((m) => m['type'] == 'ticks'));
    expect(
      ops('subscribe').single['symbols'],
      unorderedEquals(['TCS', 'INFY']),
    );
    sub.cancel();
  });

  test('reference counting: the biggest mode wins, unsubscribe only after the last cancel', () async {
    final watchlist = socket.subscribeQuotes(['TCS', 'INFY'], FeedMode.quote);
    final detail = socket.subscribeQuotes(['TCS'], FeedMode.full);
    await eventually(() => ops('subscribe').length == 2);
    expect(ops('subscribe').last, containsPair('mode', 'full'));

    detail.cancel(); // TCS goes back to quote mode, still subscribed
    await eventually(() => ops('subscribe').length == 3);
    expect(
      ops('subscribe').last,
      allOf(containsPair('mode', 'quote'), containsPair('symbols', ['TCS'])),
    );
    expect(ops('unsubscribe'), isEmpty);

    watchlist.cancel();
    await eventually(() => ops('unsubscribe').isNotEmpty);
    expect(
      ops('unsubscribe').single['symbols'],
      unorderedEquals(['TCS', 'INFY']),
    );
  });

  test(
    'quote holders use fastest throttle and linger 300 ms on final leave',
    () async {
      final first = socket.subscribeQuotes(
        ['SBIN'],
        FeedMode.quote,
        throttleMs: 700,
      );
      await eventually(() => ops('subscribe').isNotEmpty);
      expect(ops('subscribe').last['throttleMs'], 700);

      final detail = socket.subscribeQuotes(
        ['SBIN'],
        FeedMode.full,
        throttleMs: 100,
      );
      await eventually(() => ops('subscribe').length == 2);
      expect(ops('subscribe').last['mode'], 'full');
      expect(ops('subscribe').last['throttleMs'], 100);

      detail.cancel();
      await eventually(() => ops('subscribe').length == 3);
      expect(ops('subscribe').last['mode'], 'quote');
      expect(ops('subscribe').last['throttleMs'], 700);
      expect(ops('unsubscribe'), isEmpty);

      first.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final resumed = socket.subscribeQuotes(
        ['SBIN'],
        FeedMode.full,
        throttleMs: 50,
      );
      await eventually(() => ops('subscribe').length == 4);
      expect(ops('unsubscribe'), isEmpty);
      expect(ops('subscribe').last['throttleMs'], 50);

      resumed.cancel();
      await eventually(() => ops('unsubscribe').isNotEmpty);
      expect(ops('unsubscribe').single['symbols'], ['SBIN']);
    },
  );

  test(
    'server drop (4002) → reconnects at once and replays subscriptions',
    () async {
      socket.subscribeQuotes(['SBIN'], FeedMode.quote);
      await eventually(() => ops('subscribe').length == 1);
      final firstSession = (socket.status as SocketConnected).sessionId;

      await server.server.gateway.dropAll();
      await eventually(
        () =>
            socket.status is SocketConnected &&
            (socket.status as SocketConnected).sessionId != firstSession,
      );

      final reconnecting = statuses.whereType<SocketReconnecting>().first;
      expect(reconnecting.delay, Duration.zero);
      expect(reconnecting.reason, startsWith('4002'));
      await eventually(() => ops('subscribe').length == 2);
      expect(ops('subscribe').last['symbols'], ['SBIN']);
    },
  );

  test(
    'silent server → heartbeat declares the connection stale and reconnects',
    () async {
      server.server.gateway.freezeAll(const Duration(seconds: 5));
      await eventually(
        () => statuses.any(
          (s) => s is SocketReconnecting && s.reason.startsWith('no data'),
        ),
      );
      await eventually(() => socket.status is SocketConnected);
    },
  );

  test('a skipped sequence number asks for a resync', () async {
    socket.subscribeQuotes(['ITC'], FeedMode.ltp);
    await eventually(() => messages.isNotEmpty);
    server.server.gateway.skipSequence();
    server.step(5);
    await eventually(() => resyncs == 1);
  });

  test('pause closes without retrying; resume reconnects', () async {
    socket.pause();
    expect(socket.status, isA<SocketPaused>());
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(server.server.gateway.connectionCount, 0);
    socket.resume();
    await eventually(() => socket.status is SocketConnected);
  });

  test('account holders: one subscribe per channel, unsubscribe after the last cancel', () async {
    List<Object?> channels(String op) => [
      for (final m in ops(op))
        if (m['channel'] != null) m['channel'],
    ];
    final first = socket.subscribeAccount(alerts: false);
    final second = socket.subscribeAccount();
    await pumpEventQueue();
    expect(channels('subscribe'), ['orders', 'alerts']);

    second.cancel();
    await pumpEventQueue();
    expect(channels('unsubscribe'), ['alerts']);
    first.cancel();
    await pumpEventQueue();
    expect(channels('unsubscribe'), ['alerts', 'orders']);
  });

  test('account channels are subscribed again after a reconnect', () async {
    socket.subscribeAccount(alerts: false);
    server.server.gateway.freezeAll(const Duration(seconds: 5));
    await eventually(() => socket.status is SocketReconnecting);
    await eventually(() => socket.status is SocketConnected);
    await eventually(
      () => ops('subscribe').where((m) => m['channel'] == 'orders').length == 2,
    );
  });
}
