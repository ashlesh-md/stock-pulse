import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_event.dart';
import 'package:stock_pulse/core/feedback/application/feedback_controller.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';

import '../../helpers/fake_analytics_sink.dart';
import '../../helpers/fake_crash_reporter.dart';

void main() {
  late FakeClock clock;
  late ProviderContainer container;
  late FakeAnalyticsSink analyticsSink;

  FeedbackController controller() =>
      container.read(feedbackControllerProvider.notifier);
  FeedbackMessage? shown() => container.read(feedbackControllerProvider);

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 11, 7, 10));
    analyticsSink = FakeAnalyticsSink();
    container = ProviderContainer.test(
      overrides: [
        clockProvider.overrideWithValue(clock),
        analyticsProvider.overrideWithValue(
          AnalyticsService(
            [analyticsSink],
            FakeCrashReporter(),
            consent: () => true,
          ),
        ),
      ],
    );
  });

  const info = FeedbackMessage(key: 'a.info', text: 'A');
  const otherInfo = FeedbackMessage(key: 'b.info', text: 'B');
  const error = FeedbackMessage(
    key: 'x.error',
    text: 'E',
    kind: FeedbackKind.error,
  );
  const fill = FeedbackMessage(
    key: 'order.filled.1',
    text: 'Filled',
    kind: FeedbackKind.success,
    priority: FeedbackPriority.orderOutcome,
  );

  group('FeedbackMessage', () {
    test('priority defaults from kind: error → error, others → info', () {
      expect(error.priority, FeedbackPriority.error);
      expect(info.priority, FeedbackPriority.info);
      expect(
        const FeedbackMessage(
          key: 'k',
          text: 't',
          kind: FeedbackKind.success,
        ).priority,
        FeedbackPriority.info,
      );
    });

    test('equal by value, actions included', () {
      const a = FeedbackMessage(
        key: 'k',
        text: 't',
        actionLabel: 'View',
        action: OpenLocation('/portfolio'),
      );
      const b = FeedbackMessage(
        key: 'k',
        text: 't',
        actionLabel: 'View',
        action: OpenLocation('/portfolio'),
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == info, isFalse);
      expect(const ReplyToSender('new'), const ReplyToSender('new'));
      expect(
        const ReplyToSender('new').hashCode,
        const ReplyToSender('new').hashCode,
      );
      expect(
        const OpenLocation('/a').hashCode,
        const OpenLocation('/a').hashCode,
      );
      expect(
        const FeedbackReply(key: 'k', actionId: 'a'),
        const FeedbackReply(key: 'k', actionId: 'a'),
      );
      expect(
        const FeedbackReply(key: 'k', actionId: 'a').hashCode,
        const FeedbackReply(key: 'k', actionId: 'a').hashCode,
      );
    });

    test('toString names the key for logs and test failures', () {
      expect(info.toString(), contains('a.info'));
    });
  });

  group('FeedbackController (ADR-0019, FR-156, FR-157)', () {
    test('starts with nothing shown', () {
      expect(shown(), isNull);
      expect(controller().waiting, isNull);
    });

    test('FR-156: the same key five times shows one message, slot empty', () {
      for (var i = 0; i < 5; i++) {
        controller().show(error);
      }
      expect(shown(), error);
      expect(controller().waiting, isNull);
    });

    test('FR-156: a key shown under 4 s ago is dropped after dismissal', () {
      controller()
        ..show(info)
        ..dismissed(info.key);
      clock.advance(const Duration(milliseconds: 3999));
      controller().show(info);
      expect(shown(), isNull);
    });

    test('FR-156: the same key is accepted again after 4 s', () {
      controller()
        ..show(info)
        ..dismissed(info.key);
      clock.advance(const Duration(seconds: 4));
      controller().show(info);
      expect(shown(), info);
    });

    test('equal or higher priority replaces the shown message at once', () {
      controller()
        ..show(info)
        ..show(otherInfo);
      expect(shown(), otherInfo);
      controller().show(error);
      expect(shown(), error);
      controller().show(fill);
      expect(shown(), fill);
      expect(controller().waiting, isNull);
    });

    test('FR-157: lower messages wait in one slot, newest wins', () {
      controller()
        ..show(fill)
        ..show(info)
        ..show(otherInfo);
      expect(shown(), fill);
      expect(controller().waiting, otherInfo);

      controller().dismissed(fill.key);

      expect(shown(), otherInfo);
      expect(controller().waiting, isNull);
    });

    test('dismissing with nothing waiting clears the screen', () {
      controller()
        ..show(info)
        ..dismissed(info.key);
      expect(shown(), isNull);
    });

    test('dismissed for a key not on screen changes nothing', () {
      controller()
        ..show(fill)
        ..show(info)
        ..dismissed('stale.key');
      expect(shown(), fill);
      expect(controller().waiting, info);
    });

    test('clear drops the shown and the waiting message', () {
      controller()
        ..show(fill)
        ..show(info)
        ..clear();
      expect(shown(), isNull);
      expect(controller().waiting, isNull);
    });

    test('error_shown logs its code once when an error is displayed', () {
      controller()
        ..show(error)
        ..show(error);

      expect(analyticsSink.events, [
        const AnalyticsEvent('error_shown', {'code': 'error'}),
      ]);
    });

    test('ReplyToSender taps reach replies with key and action id', () async {
      const startNew = FeedbackMessage(
        key: 'strategy.otherChain',
        text: 'Other chain',
        actionLabel: 'Start new',
        action: ReplyToSender('startNew'),
      );
      final replies = <FeedbackReply>[];
      final sub = controller().replies.listen(replies.add);
      addTearDown(sub.cancel);

      controller()
        ..actionTapped(startNew)
        ..actionTapped(info);
      await pumpEventQueue();

      expect(replies, [
        const FeedbackReply(key: 'strategy.otherChain', actionId: 'startNew'),
      ]);
    });
  });
}
