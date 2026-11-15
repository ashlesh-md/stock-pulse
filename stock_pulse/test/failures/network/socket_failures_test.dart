import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/data/frame_decoder.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/data/socket_config.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/core/network/domain/subscriptions.dart';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../helpers/fake_crash_reporter.dart';

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

/// One fake WebSocket connection: push server frames with [serve], read
/// what the client sent from [sentOps].
class _FakeChannel implements WebSocketChannel {
  final incoming = StreamController<Object?>();
  final _sink = _Sink();

  @override
  final Future<void> ready = Future.value();

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

  bool get closed => _sink._done.isCompleted;

  void serve(Map<String, Object?> frame) => incoming.add(jsonEncode(frame));

  /// The `op` of every JSON frame the client sent.
  List<Object?> get sentOps => [
    for (final text in _sink.sent)
      (jsonDecode(text! as String) as Map<String, Object?>)['op'],
  ];

  Future<void> drop() async {
    await incoming.close();
    await _sink.close();
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  final uri = Uri.parse('ws://test');
  const config = SocketConfig(maxBackoff: Duration(milliseconds: 1));

  late List<_FakeChannel> channels;
  late FakeCrashReporter reporter;
  late FrameDropCounter drops;
  late MarketSocket socket;
  late List<Map<String, Object?>> messages;

  setUp(() {
    channels = [];
    reporter = FakeCrashReporter();
    drops = FrameDropCounter(reporter.log);
    messages = [];
    socket = MarketSocket(
      uri,
      config: config,
      drops: drops,
      connect: (_) {
        final channel = _FakeChannel();
        channels.add(channel);
        return channel;
      },
    );
    socket.messages.listen(messages.add);
  });
  tearDown(() => socket.dispose());

  Future<_FakeChannel> connected({String session = 's1'}) async {
    socket.start();
    await settle();
    final channel = channels.last
      ..serve({'type': 'welcome', 'sessionId': session, 'serverTime': 1});
    await settle();
    return channel;
  }

  group('F6 a bad socket frame', () {
    test('is dropped and counted, and the connection stays open', () async {
      final channel = await connected();

      channel.incoming
        ..add('{not json')
        ..add('[1, 2]')
        ..add(jsonEncode({'seq': 3}));
      await settle();

      expect(drops.count, 3);
      expect(socket.status, isA<SocketConnected>());
      expect(channel.closed, isFalse);
      expect(messages.map((m) => m['type']), ['welcome']);
    });

    test('is logged once per kind, however often it repeats', () async {
      final channel = await connected();

      for (var i = 0; i < 5; i++) {
        channel.incoming
          ..add('{not json')
          ..add(jsonEncode({'type': 7}));
      }
      await settle();

      expect(drops.count, 10);
      expect(
        reporter
            .logsNamed('socket_frame_dropped')
            .map((log) => log.data['reason']),
        ['not_json', 'no_type'],
      );
    });

    test('a frame after the bad one is still delivered', () async {
      final channel = await connected();
      socket.subscribeQuotes(['TCS'], FeedMode.ltp);

      channel.incoming.add('{not json');
      channel.serve({'type': 'ticks', 'seq': 1, 'data': <Object?>[]});
      await settle();

      expect(messages.last['type'], 'ticks');
    });
  });

  group('F7 server restart', () {
    test(
      'the new session id is accepted and its seq restart is no gap',
      () async {
        final first = await connected();
        first
          ..serve({'type': 'ticks', 'seq': 500, 'data': <Object?>[]})
          ..serve({'type': 'ticks', 'seq': 501, 'data': <Object?>[]});
        await settle();

        await first.drop();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(channels, hasLength(2));
        final second = channels.last
          ..serve({'type': 'welcome', 'sessionId': 's2', 'serverTime': 2})
          ..serve({'type': 'ticks', 'seq': 1, 'data': <Object?>[]})
          ..serve({'type': 'ticks', 'seq': 2, 'data': <Object?>[]});
        await settle();

        expect(
          socket.status,
          isA<SocketConnected>().having((s) => s.sessionId, 'session', 's2'),
        );
        expect(second.sentOps.where((op) => op == 'resync'), isEmpty);
      },
    );

    test('a reconnect runs one full resync of registered reloaders', () async {
      var reloads = 0;
      socket.registerResyncReloader(() async => reloads++);
      final first = await connected();
      expect(reloads, 1);

      await first.drop();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      channels.last.serve({'type': 'welcome', 'sessionId': 's2'});
      await settle();

      expect(reloads, 2);
    });
  });

  test(
    'F2 a dropped connection reports Reconnecting with its reason',
    () async {
      final statuses = <SocketStatus>[];
      final sub = socket.statusChanges.listen(statuses.add);
      addTearDown(sub.cancel);
      final channel = await connected();

      await channel.drop();
      await settle();

      expect(
        statuses.whereType<SocketReconnecting>().first.reason,
        'connection lost',
      );
    },
  );
}
