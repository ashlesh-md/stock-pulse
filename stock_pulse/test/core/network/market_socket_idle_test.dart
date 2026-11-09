import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _Sink implements WebSocketSink {
  @override
  void add(Object? data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Object?> stream) async {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}

  @override
  Future<void> get done => Completer<void>().future;
}

class _FakeChannel implements WebSocketChannel {
  // ignore: close_sinks, the socket under test owns the stream's lifetime.
  final incoming = StreamController<Object?>();

  @override
  Future<void> get ready => Future.value();

  @override
  Stream<Object?> get stream => incoming.stream;

  @override
  WebSocketSink get sink => _Sink();

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeClock clock;
  late _FakeChannel channel;
  late MarketSocket socket;
  final opened = DateTime.utc(2026, 11, 9, 10);

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    clock = FakeClock(opened);
    channel = _FakeChannel();
    socket = MarketSocket(
      Uri.parse('ws://test'),
      clock: clock,
      connect: (_) => channel,
    )..start();
    await settle();
    channel.incoming.add(jsonEncode({'type': 'welcome', 'sessionId': 'S'}));
    await settle();
  });

  tearDown(() => socket.dispose());

  test('B22: a connected socket with no quote or chain subscription is '
      'never silent, so no screen subscribing nothing reads as stale', () {
    clock.advance(const Duration(seconds: 30));

    expect(socket.lastFrameAt, clock.now());
  });

  test('B22: the silence clock starts when the first quote is subscribed, '
      'not at the last frame before the idle spell', () async {
    clock.advance(const Duration(seconds: 30));
    final subscribedAt = clock.now();

    final sub = socket.subscribeQuotes(['TCS'], FeedMode.ltp);
    clock.advance(const Duration(seconds: 6));

    expect(socket.lastFrameAt, subscribedAt);
    sub.cancel();
  });

  test('B22: a socket that is not connected keeps its last data frame', () {
    socket.pause();
    clock.advance(const Duration(seconds: 30));

    expect(socket.lastFrameAt, opened);
  });
}
