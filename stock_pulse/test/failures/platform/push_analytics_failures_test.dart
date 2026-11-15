import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/push_link_handler.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_event.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_sink.dart';
import 'package:stock_pulse/core/push/domain/push_service.dart';

import '../../helpers/fake_analytics_sink.dart';
import '../../helpers/fake_crash_reporter.dart';

class _Push implements PushService {
  _Push({this.tokenError});

  final Object? tokenError;
  final taps = StreamController<PushMessage>.broadcast();

  Future<void> dispose() async {
    await taps.close();
  }

  @override
  Future<void> init() async {}

  @override
  Future<String?> token() async {
    if (tokenError case final Exception error) throw error;
    return 'token';
  }

  @override
  Future<PushMessage?> initialMessage() async => null;

  @override
  Stream<PushMessage> get onTap => taps.stream;

  @override
  Stream<PushMessage> get onForeground => const Stream.empty();
}

class _Router extends Fake implements GoRouter {
  final visited = <String>[];

  @override
  void go(String location, {Object? extra}) => visited.add(location);
}

class _BrokenSink implements AnalyticsSink {
  int calls = 0;

  @override
  String get id => 'broken';

  @override
  Future<void> log(AnalyticsEvent event) async {
    calls++;
    throw StateError('sink down');
  }

  @override
  Future<void> setUserProperty(String name, String? value) async =>
      throw StateError('sink down');

  @override
  Future<void> reset() async => throw StateError('sink down');
}

class _HangingSink extends FakeAnalyticsSink {
  @override
  Future<void> log(AnalyticsEvent event) => Completer<void>().future;
}

void main() {
  late FakeCrashReporter reporter;
  late _Router router;
  late int invalidLinks;

  setUp(() {
    reporter = FakeCrashReporter();
    router = _Router();
    invalidLinks = 0;
  });

  PushLinkHandler handlerFor(_Push push) {
    final handler = PushLinkHandler(
      push,
      router,
      AnalyticsService([FakeAnalyticsSink()], reporter, consent: () => true),
      reporter,
      onInvalidLink: () => invalidLinks++,
    );
    addTearDown(handler.dispose);
    addTearDown(push.dispose);
    return handler;
  }

  test('F15 a push token failure falls back to no push, logged once, and '
      'taps still open', () async {
    final push = _Push(tokenError: Exception('no token'));
    final handler = handlerFor(push);

    await handler.start();
    push.taps.add(
      PushMessage(id: 'p1', link: Uri.parse('stockpulse://app/stock/TCS')),
    );
    await pumpEventQueue();

    expect(reporter.errors.map((e) => e.reason), ['push_unavailable']);
    expect(router.visited, ['/stock/TCS']);
  });

  test('F14 a push with a refused link lands on the watchlist with one '
      'link-not-available notice', () async {
    final push = _Push();
    final handler = handlerFor(push);
    await handler.start();

    push.taps
      ..add(PushMessage(id: 'p2', link: Uri.parse('https://evil.test/x')))
      ..add(PushMessage(id: 'p2', link: Uri.parse('https://evil.test/x')));
    await pumpEventQueue();

    expect(router.visited, [WatchlistRoute.path]);
    expect(invalidLinks, 1);
    expect(reporter.logsNamed('push_link_refused'), hasLength(1));
  });

  test('F14 a push of a type with nothing to open is ignored and logged '
      'once', () async {
    final push = _Push();
    final handler = handlerFor(push);
    await handler.start();

    push.taps.add(const PushMessage(id: 'p3'));
    await pumpEventQueue();

    expect(router.visited, isEmpty);
    expect(reporter.logsNamed('push_ignored'), hasLength(1));
  });

  group('F16 analytics sink', () {
    test(
      'that throws on every call is reported once and never crashes',
      () async {
        final broken = _BrokenSink();
        final good = FakeAnalyticsSink();
        final service = AnalyticsService(
          [broken, good],
          reporter,
          consent: () => true,
        );

        for (var i = 0; i < 10; i++) {
          service.logEvent(
            const AnalyticsEvent('screen_view', {'screen': 'w'}),
          );
        }
        await service.setUserProperty('theme', 'dark');
        await service.reset();
        await pumpEventQueue();

        expect(broken.calls, 10);
        expect(good.events, hasLength(10));
        expect(reporter.errors.map((e) => e.reason), ['analytics_sink_failed']);
      },
    );

    test('that never answers does not block the caller', () {
      final good = FakeAnalyticsSink();
      final service = AnalyticsService(
        [_HangingSink(), good],
        reporter,
        consent: () => true,
      );

      service.logEvent(const AnalyticsEvent('screen_view', {'screen': 'w'}));

      expect(good.events, hasLength(1));
      expect(reporter.errors, isEmpty);
    });
  });
}
