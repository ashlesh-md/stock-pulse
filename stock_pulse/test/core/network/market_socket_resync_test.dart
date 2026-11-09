import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/data/socket_config.dart';
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

  test(
    'a sequence gap sends one resync and runs registered reloaders',
    () async {
      final channel = _FakeChannel();
      final socket = MarketSocket(uri, config: config, connect: (_) => channel)
        ..start();
      var reloads = 0;
      var completions = 0;
      var starts = 0;
      final removeReloader = socket.registerResyncReloader(() async {
        reloads++;
      });
      final started = socket.resyncStarted.listen((_) => starts++);
      final completed = socket.resyncCompleted.listen((_) => completions++);
      await settle();
      channel.incoming.add(jsonEncode({'type': 'welcome', 'sessionId': 'S1'}));
      await settle();
      await settle();
      expect(reloads, 1);
      expect(starts, 1);
      expect(completions, 1);
      channel.incoming
        ..add(jsonEncode({'type': 'ticks', 'seq': 1}))
        ..add(jsonEncode({'type': 'ticks', 'seq': 3}))
        ..add(jsonEncode({'type': 'ticks', 'seq': 4}));
      await settle();
      await settle();
      final ops = [
        for (final raw in channel._sink.sent)
          jsonDecode(raw! as String) as Map<String, Object?>,
      ];
      expect(ops.where((op) => op['op'] == 'resync'), hasLength(1));
      expect(reloads, 2);
      expect(starts, 2);
      expect(completions, 2);
      removeReloader();
      await started.cancel();
      await completed.cancel();
      await socket.dispose();
      await channel.shutDown();
    },
  );

  test('reconnect completion waits for every account reloader', () async {
    final channel = _FakeChannel();
    final socket = MarketSocket(uri, config: config, connect: (_) => channel)
      ..start();
    final orders = Completer<void>();
    final positions = Completer<void>();
    final alerts = Completer<void>();
    var reloads = 0;
    var completions = 0;
    final removers = [
      for (final gate in [orders, positions, alerts])
        socket.registerResyncReloader(() async {
          reloads++;
          await gate.future;
        }),
    ];
    final completed = socket.resyncCompleted.listen((_) => completions++);
    await settle();

    channel.incoming.add(jsonEncode({'type': 'welcome', 'sessionId': 'S1'}));
    await settle();
    await settle();
    expect(reloads, 3);
    expect(completions, 0);

    orders.complete();
    await settle();
    expect(completions, 0);
    positions.complete();
    alerts.complete();
    await settle();
    await settle();
    expect(completions, 1);

    for (final remove in removers) {
      remove();
    }
    await completed.cancel();
    await socket.dispose();
    await channel.shutDown();
  });
}
