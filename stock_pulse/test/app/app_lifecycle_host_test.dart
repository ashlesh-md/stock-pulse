import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';

import 'app_harness.dart';

void main() {
  testWidgets('FR-85: hidden pauses the socket, shown resumes it', (
    tester,
  ) async {
    final h = AppHarness();
    await tester.pumpWidget(h.app());

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(h.socket.paused, isTrue);
    expect(h.socket.pauseCount, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(h.socket.paused, isFalse);
    expect(h.socket.resumeCount, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('analytics preference load failures are reported', (
    tester,
  ) async {
    final h = AppHarness()..prefsUnavailable = true;
    await tester.pumpWidget(h.app());
    await tester.pump();
    await tester.pump();

    expect(h.reporter.errors, hasLength(1));
    expect(h.reporter.errors.single.reason, 'analytics_app_open');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('connection analytics are throttled to one event per minute', (
    tester,
  ) async {
    final h = AppHarness();
    await h.pumpPhone(tester);
    await tester.pump();

    h.socket.setStatus(const SocketConnected(sessionId: 'one'));
    await tester.pump();
    h.socket.setStatus(
      const SocketReconnecting(
        attempt: 1,
        delay: Duration(seconds: 1),
        reason: 'test',
      ),
    );
    await tester.pump();
    final liveName = Events.connectionChanged('live').name;
    expect(
      h.analyticsSink.events.where((event) => event.name == liveName),
      hasLength(1),
    );

    h.clock.advance(const Duration(minutes: 1));
    h.socket.setStatus(const SocketConnected(sessionId: 'two'));
    await tester.pump();
    expect(
      h.analyticsSink.events.where((event) => event.name == liveName),
      hasLength(2),
    );
    await tester.pumpWidget(const SizedBox());
  });
}
