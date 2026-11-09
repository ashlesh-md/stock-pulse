import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/network/data/frame_decoder.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/data/socket_config.dart';
import 'package:stock_pulse/core/network/domain/chain_request.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Sink implements WebSocketSink {
  final sent = <Object?>[];
  final _done = Completer<void>();

  @override
  void add(Object? data) => sent.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Object?> stream) async {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}

class _FakeChannel implements WebSocketChannel {
  _FakeChannel({Future<void>? ready}) : ready = ready ?? Future.value();

  final incoming = StreamController<Object?>();
  final _sink = _Sink();

  @override
  final Future<void> ready;

  @override
  Stream<Object?> get stream => incoming.stream;

  @override
  WebSocketSink get sink => _sink;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  Future<void> shutDown() async {
    await incoming.close();
    await _sink.close();
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final uri = Uri.parse('ws://test');
  const config = SocketConfig(maxBackoff: Duration(milliseconds: 1));

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a failed handshake reconnects with reason connect failed', () async {
    final channels = <_FakeChannel>[];
    final socket = MarketSocket(
      uri,
      config: config,
      connect: (_) {
        final c = _FakeChannel(
          ready: channels.isEmpty
              ? Future.error(WebSocketChannelException('refused'))
              : null,
        );
        channels.add(c);
        return c;
      },
    );
    final statuses = <SocketStatus>[];
    socket.statusChanges.listen(statuses.add);
    socket.start();
    await settle();
    final reconnecting = statuses.whereType<SocketReconnecting>().first;
    expect(reconnecting.reason, 'connect failed');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(channels, hasLength(2));
    await socket.dispose();
  });

  test('pausing during the handshake drops that connection', () async {
    final ready = Completer<void>();
    final channel = _FakeChannel(ready: ready.future);
    final socket = MarketSocket(uri, config: config, connect: (_) => channel)
      ..start();
    socket.pause();
    ready.complete();
    await settle();
    expect(channel._sink._done.isCompleted, isTrue);
    expect(socket.status, isA<SocketPaused>());
    await socket.dispose();
  });

  test('a paused socket does not reconnect over ten seconds', () async {
    var connections = 0;
    final socket = MarketSocket(
      uri,
      config: config,
      connect: (_) {
        connections++;
        return _FakeChannel();
      },
    )..start();
    await settle();
    socket.pause();

    await Future<void>.delayed(const Duration(seconds: 10));

    expect(connections, 1);
    expect(socket.status, isA<SocketPaused>());
    await socket.dispose();
  });

  test('a stream error closes the connection with socket error', () async {
    final channel = _FakeChannel();
    final socket = MarketSocket(uri, config: config, connect: (_) => channel)
      ..start();
    await settle();
    final next = socket.statusChanges.firstWhere(
      (s) => s is SocketReconnecting,
    );
    channel.incoming.addError(StateError('boom'));
    expect((await next as SocketReconnecting).reason, 'socket error');
    await socket.dispose();
    await channel.shutDown();
  });

  test('a binary frame is decoded and stamps lastFrameAt', () async {
    final channel = _FakeChannel();
    final clock = FakeClock(DateTime.utc(2026, 11, 10, 4));
    final socket = MarketSocket(
      uri,
      config: config,
      clock: clock,
      connect: (_) => channel,
    );
    final quotes = socket.subscribeQuotes(['TCS'], FeedMode.ltp);
    socket.start();
    await settle();
    expect(socket.lastFrameAt, isNull);
    channel.incoming.add(
      utf8.encode(jsonEncode({'type': 'welcome', 'sessionId': 'S9'})),
    );
    await settle();
    expect(socket.lastFrameAt, clock.now());
    expect(socket.status, isA<SocketConnected>());
    quotes.cancel();
    await socket.dispose();
  });

  test(
    'a pong does not count as data, so a silent feed can go Delayed',
    () async {
      final channel = _FakeChannel();
      final clock = FakeClock(DateTime.utc(2026, 11, 10, 4));
      final socket = MarketSocket(
        uri,
        config: config,
        clock: clock,
        connect: (_) => channel,
      )..start();
      await settle();
      channel.incoming.add(jsonEncode({'type': 'welcome', 'sessionId': 'S1'}));
      await settle();
      final welcomedAt = clock.now();
      final quotes = socket.subscribeQuotes(['TCS'], FeedMode.ltp);
      clock.advance(const Duration(seconds: 3));
      channel.incoming.add(jsonEncode({'type': 'pong', 'ts': 1}));
      await settle();
      expect(socket.lastFrameAt, welcomedAt);
      channel.incoming.add(
        jsonEncode({'type': 'ka', 'seq': 1, 'quotes': <String>[]}),
      );
      await settle();
      expect(socket.lastFrameAt, clock.now());
      quotes.cancel();
      await socket.dispose();
    },
  );

  test(
    'a chain holder subscribes, widens its range and unsubscribes',
    () async {
      final channel = _FakeChannel();
      final socket = MarketSocket(uri, config: config, connect: (_) => channel)
        ..start();
      await settle();
      List<Map<String, Object?>> ops() => [
        for (final raw in channel._sink.sent)
          jsonDecode(raw! as String) as Map<String, Object?>,
      ];
      final holder = socket.subscribeChain(
        const ChainRequest(
          underlying: 'NIFTY',
          expiry: '2026-11-10',
          fromStrike: 100,
          toStrike: 200,
        ),
      );
      holder.updateRange(50, 250);
      holder.cancel();
      expect(ops().where((o) => o['channel'] == 'chain').toList(), [
        {
          'op': 'subscribe',
          'id': 1,
          'channel': 'chain',
          'underlying': 'NIFTY',
          'expiry': '2026-11-10',
          'fromStrike': 100,
          'toStrike': 200,
        },
        containsPair('fromStrike', 50),
        {
          'op': 'unsubscribe',
          'id': 3,
          'channel': 'chain',
          'underlying': 'NIFTY',
          'expiry': '2026-11-10',
        },
      ]);
      await socket.dispose();
    },
  );

  test('a quote holder can return during the 300 ms linger window', () async {
    final channel = _FakeChannel();
    final socket = MarketSocket(uri, config: config, connect: (_) => channel)
      ..start();
    await settle();
    List<Map<String, Object?>> ops() => [
      for (final raw in channel._sink.sent)
        jsonDecode(raw! as String) as Map<String, Object?>,
    ];
    final first = socket.subscribeQuotes(['TCS'], FeedMode.quote);
    first.cancel();
    final replacement = socket.subscribeQuotes(['TCS'], FeedMode.full);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    expect(ops().where((op) => op['op'] == 'unsubscribe'), isEmpty);
    expect(
      ops().where((op) => op['op'] == 'subscribe').last['mode'],
      FeedMode.full.name,
    );
    replacement.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    expect(ops().where((op) => op['op'] == 'unsubscribe'), hasLength(1));
    await socket.dispose();
  });

  test('subscribeChain hands back a holder for the request', () {
    const req = ChainRequest(
      underlying: 'NIFTY',
      expiry: '2026-11-10',
      fromStrike: 1,
      toStrike: 2,
    );
    final socket = MarketSocket(uri, connect: (_) => _FakeChannel());
    expect(socket.subscribeChain(req).request, req);
  });

  test('decodeFrame drops text that is not a JSON object', () {
    expect(decodeFrame('{bad'), isNull);
    expect(decodeFrame('[1]'), isNull);
    expect(decodeFrame('{"a":1}'), {'a': 1});
  });
}
