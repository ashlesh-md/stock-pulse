import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/config/app_config.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/locales/en/more_strings_en.dart';
import 'package:stock_pulse/core/network/data/api_client.dart';
import 'package:stock_pulse/core/network/data/market_socket.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/features/more/application/socket_lab_state.dart';
import 'package:stock_pulse/features/more/di/more_providers.dart';
import 'package:stock_pulse/features/more/domain/chaos.dart';

import '../../helpers/fake_crash_reporter.dart';

class _FrameSocket extends Fake implements MarketSocket {
  final controller = StreamController<SocketFrame>.broadcast(sync: true);

  @override
  Stream<SocketFrame> get frames => controller.stream;

  void add(String text, {bool outgoing = false}) => controller.add(
    SocketFrame(outgoing: outgoing, text: text, at: DateTime.utc(2026)),
  );
}

void main() {
  late _FrameSocket socket;
  late List<String> posted;
  late int status;

  ProviderContainer make() => ProviderContainer.test(
    overrides: [
      analyticsProvider.overrideWithValue(
        AnalyticsService(const [], FakeCrashReporter(), consent: () => false),
      ),
      marketSocketProvider.overrideWithValue(socket),
      apiClientProvider.overrideWithValue(
        ApiClient(
          const AppConfig(host: 'localhost'),
          client: MockClient((r) async {
            posted.add(r.url.path);
            return http.Response('{}', status);
          }),
        ),
      ),
    ],
  );

  setUp(() {
    socket = _FrameSocket();
    posted = [];
    status = 200;
  });

  test('FR-110: counts frames in and out and keeps the newest first', () {
    final c = make();
    c.listen(socketLabControllerProvider, (_, _) {});

    socket
      ..add('abc')
      ..add('{"op":"sub"}', outgoing: true)
      ..add('de');

    final s = c.read(socketLabControllerProvider);
    expect(s.received, 2);
    expect(s.sent, 1);
    expect(s.bytesIn, 5);
    expect(s.frames.map((f) => f.text), ['de', '{"op":"sub"}', 'abc']);
  });

  test('paused keeps counting but freezes the log; clear empties it', () {
    final c = make();
    c.listen(socketLabControllerProvider, (_, _) {});
    final lab = c.read(socketLabControllerProvider.notifier);
    socket.add('a');

    lab.togglePause();
    socket.add('b');
    expect(c.read(socketLabControllerProvider).frames, hasLength(1));
    expect(c.read(socketLabControllerProvider).received, 2);

    lab
      ..togglePause()
      ..clear();
    expect(c.read(socketLabControllerProvider).frames, isEmpty);
    expect(c.read(socketLabControllerProvider).paused, isFalse);
  });

  test('FR-111: the log keeps the newest 500 of 600 frames', () {
    final c = make();
    c.listen(socketLabControllerProvider, (_, _) {});
    for (var i = 0; i < 600; i++) {
      socket.add('$i');
    }
    final state = c.read(socketLabControllerProvider);
    expect(state.frames, hasLength(500));
    expect(state.frames.first.text, '599');
    expect(state.frames.last.text, '100');
    expect(state.received, 600);
  });

  test('a chaos button posts its endpoint and explains it once', () async {
    final c = make();
    c.listen(socketLabControllerProvider, (_, _) {});

    await c.read(socketLabControllerProvider.notifier).trigger(Chaos.freeze);

    expect(posted, ['/debug/freeze']);
    final shown = c.read(feedbackControllerProvider)!;
    expect(shown.key, 'socketLab.chaos.freeze');
    expect(shown.text, const MoreStringsEn().freezeExplained);
    expect(shown.kind, FeedbackKind.info);
  });

  test(
    'a refused chaos call shows the error text, never the raw message',
    () async {
      status = 500;
      final c = make();
      c.listen(socketLabControllerProvider, (_, _) {});

      await c.read(socketLabControllerProvider.notifier).trigger(Chaos.drop);

      final shown = c.read(feedbackControllerProvider)!;
      expect(shown.key, 'socketLab.failed.drop');
      expect(shown.kind, FeedbackKind.error);
    },
  );

  test('state is a value', () {
    const a = SocketLabState(received: 1);
    expect(a, const SocketLabState(received: 1));
    expect(a.hashCode, const SocketLabState(received: 1).hashCode);
    expect(a == const SocketLabState(), isFalse);
  });
}
