import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/push/domain/push_service.dart';

import 'app_harness.dart';

class _PushService implements PushService {
  final taps = StreamController<PushMessage>.broadcast(sync: true);
  final foreground = StreamController<PushMessage>.broadcast(sync: true);

  Future<void> dispose() async {
    await taps.close();
    await foreground.close();
  }

  @override
  Future<void> init() async {}

  @override
  Future<String?> token() async => null;

  @override
  Future<PushMessage?> initialMessage() async => null;

  @override
  Stream<PushMessage> get onTap => taps.stream;

  @override
  Stream<PushMessage> get onForeground => foreground.stream;
}

void main() {
  testWidgets('push provider reports invalid links and shows safe foreground '
      'actions', (tester) async {
    final harness = AppHarness();
    final push = _PushService();
    harness.pushService = push;
    addTearDown(push.dispose);
    await harness.pumpPhone(tester);
    await tester.pumpAndSettle();

    push.taps.add(
      PushMessage(
        id: 'invalid',
        link: Uri.parse('https://evil.example/stock/X'),
      ),
    );
    await tester.pump();
    expect(
      harness.container(tester).read(feedbackControllerProvider)?.key,
      'links.not_available',
    );

    push.foreground.add(
      PushMessage(
        id: 'foreground',
        title: 'Price alert',
        type: PushMessageType.alert,
        link: Uri.parse('stockpulse://app/stock/RELIANCE'),
      ),
    );
    await tester.pump();
    final feedback = harness.container(tester).read(feedbackControllerProvider);
    expect(feedback?.key, 'push.foreground.foreground');
    expect(feedback?.actionLabel, isNotNull);
    expect(feedback?.action, isNotNull);
  });
}
