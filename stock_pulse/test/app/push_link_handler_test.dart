import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/push_link_handler.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/push/domain/push_service.dart';

import '../helpers/fake_analytics_sink.dart';
import '../helpers/fake_crash_reporter.dart';

class _Push implements PushService {
  final taps = StreamController<PushMessage>();
  final foreground = StreamController<PushMessage>();
  PushMessage? initial;
  Object? initError;
  Future<void>? initGate;

  Future<void> dispose() async {
    await taps.close();
    await foreground.close();
  }

  @override
  Future<void> init() async {
    await initGate;
    switch (initError) {
      case final Error error:
        throw error;
      case final Exception error:
        throw error;
    }
  }

  @override
  Future<String?> token() async => 'token';

  @override
  Future<PushMessage?> initialMessage() async => initial;

  @override
  Stream<PushMessage> get onTap => taps.stream;

  @override
  Stream<PushMessage> get onForeground => foreground.stream;
}

class _Router extends Fake implements GoRouter {
  final visited = <String>[];

  @override
  void go(String location, {Object? extra}) => visited.add(location);
}

void main() {
  late _Push push;
  late _Router router;
  late FakeAnalyticsSink sink;
  late FakeCrashReporter reporter;
  late PushLinkHandler handler;
  late List<(PushMessage, String?)> foregroundMessages;
  late Set<String> seenAlertIds;

  setUp(() {
    push = _Push();
    router = _Router();
    sink = FakeAnalyticsSink();
    reporter = FakeCrashReporter();
    foregroundMessages = [];
    seenAlertIds = {};
    handler = PushLinkHandler(
      push,
      router,
      AnalyticsService([sink], reporter, consent: () => true),
      reporter,
      alertAlreadySeen: seenAlertIds.contains,
      onForegroundMessage: (message, path) =>
          foregroundMessages.add((message, path)),
    );
  });
  tearDown(() async {
    await handler.dispose();
    await push.dispose();
  });

  PushMessage msg(
    String id, [
    String? link,
    PushMessageType type = PushMessageType.system,
  ]) => PushMessage(
    id: id,
    type: type,
    link: link == null ? null : Uri.parse(link),
  );

  test('the launch message opens its screen and is logged', () async {
    push.initial = msg('1', 'stockpulse://app/stock/TCS');
    await handler.start();
    await pumpEventQueue();
    expect(router.visited, ['/stock/TCS']);
    expect(sink.events, hasLength(2));
    expect(sink.events.first.params, {'path': '/stock/:id', 'via': 'push'});
    expect(sink.events.last.name, 'push_opened');
    expect(sink.events.last.params, {'type': 'system'});
  });

  test('taps open once per id; unsafe links go to the watchlist; no link '
      'is ignored', () async {
    await handler.start();
    push.taps
      ..add(msg('a', 'stockpulse://app/portfolio'))
      ..add(msg('a', 'stockpulse://app/portfolio'))
      ..add(msg('b', 'https://evil.example/stock/X'))
      ..add(msg('c'));
    await pumpEventQueue();
    expect(router.visited, ['/portfolio', '/watchlist']);
    expect(reporter.logsNamed('push_link_refused'), hasLength(1));
    expect(reporter.logsNamed('push_ignored'), hasLength(1));
  });

  test('remembers at most 500 ids, forgetting the oldest', () async {
    await handler.start();
    for (var i = 0; i <= 500; i++) {
      push.taps.add(msg('$i'));
    }
    push.taps.add(msg('0', 'stockpulse://app/ai'));
    await pumpEventQueue();
    expect(router.visited, ['/ai']);
  });

  test('foreground notifications expose only a validated View path', () async {
    await handler.start();
    push.foreground
      ..add(msg('safe', 'stockpulse://app/stock/RELIANCE'))
      ..add(msg('unsafe', 'https://attacker.example/stock/RELIANCE'));
    await pumpEventQueue();
    expect(foregroundMessages.map((entry) => entry.$2), [
      '/stock/RELIANCE',
      null,
    ]);
  });

  test('foreground stream errors are reported', () async {
    await handler.start();
    push.foreground.addError(StateError('foreground failed'));
    await pumpEventQueue();
    expect(reporter.errors.single.reason, 'push_foreground_stream');
  });

  test(
    'foreground alert already seen in preferences does not show twice',
    () async {
      await handler.start();
      seenAlertIds.add('alert-1');
      push.foreground.add(
        msg(
          'alert-1',
          'stockpulse://app/stock/RELIANCE',
          PushMessageType.alert,
        ),
      );
      await pumpEventQueue();
      expect(foregroundMessages, isEmpty);
    },
  );

  test('a push service that fails to start is reported, not thrown', () async {
    push.initError = StateError('no permission');
    await handler.start();
    expect(reporter.errors.single.reason, 'push_unavailable');
  });

  test('stream errors are reported; after dispose nothing opens', () async {
    final gate = Completer<void>();
    push
      ..initial = msg('late', 'stockpulse://app/ai')
      ..initGate = gate.future;
    final starting = handler.start();
    push.taps.addError(StateError('boom'));
    await pumpEventQueue();
    await handler.dispose();
    gate.complete();
    await starting;
    await pumpEventQueue();
    expect(router.visited, isEmpty);
    expect(reporter.errors.single.reason, 'push_stream');
  });
}
