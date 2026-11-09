import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/feedback/presentation/feedback_host.dart';
import 'package:stock_pulse/core/feedback/presentation/sp_snack.dart';

import '../../helpers/fake_analytics_sink.dart';
import '../../helpers/fake_crash_reporter.dart';

void main() {
  late ProviderContainer container;
  final opened = <String>[];

  Future<void> pump(WidgetTester tester) async {
    container = ProviderContainer.test(
      overrides: [
        analyticsProvider.overrideWithValue(
          AnalyticsService(
            [FakeAnalyticsSink()],
            FakeCrashReporter(),
            consent: () => true,
          ),
        ),
      ],
    );
    opened.clear();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (_, child) =>
              FeedbackHost(onOpenLocation: opened.add, child: child!),
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );
  }

  void show(FeedbackMessage m) =>
      container.read(feedbackControllerProvider.notifier).show(m);

  testWidgets('CR-1.2: five identical messages give one snackbar', (
    tester,
  ) async {
    await pump(tester);
    for (var i = 0; i < 5; i++) {
      show(const FeedbackMessage(key: 'a', text: 'Once'));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Once'), findsOneWidget);
    expect(find.byIcon(AppIcons.info), findsOneWidget);
  });

  testWidgets('a new message replaces the visible one, never stacks', (
    tester,
  ) async {
    await pump(tester);
    show(const FeedbackMessage(key: 'a', text: 'First'));
    await tester.pumpAndSettle();
    show(
      const FeedbackMessage(key: 'b', text: 'Second', kind: FeedbackKind.error),
    );
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byIcon(AppIcons.error), findsOneWidget);
  });

  testWidgets('closes after 4 s and tells the controller', (tester) async {
    await pump(tester);
    show(
      const FeedbackMessage(
        key: 'ok',
        text: 'Done',
        kind: FeedbackKind.success,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.success), findsOneWidget);
    await tester.pump(FeedbackHost.shortFor);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(container.read(feedbackControllerProvider), isNull);
  });

  testWidgets('persist shows a close icon and stays', (tester) async {
    await pump(tester);
    show(const FeedbackMessage(key: 'r', text: 'Rejected', persist: true));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('OpenLocation action calls onOpenLocation', (tester) async {
    await pump(tester);
    show(
      const FeedbackMessage(
        key: 'v',
        text: 'Filled',
        actionLabel: 'View',
        action: OpenLocation('/portfolio'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    expect(opened, ['/portfolio']);
  });

  testWidgets('ReplyToSender action reaches replies', (tester) async {
    await pump(tester);
    final replies = <FeedbackReply>[];
    final sub = container
        .read(feedbackControllerProvider.notifier)
        .replies
        .listen(replies.add);
    addTearDown(sub.cancel);
    show(
      const FeedbackMessage(
        key: 's',
        text: 'Other chain',
        actionLabel: 'Start new',
        action: ReplyToSender('startNew'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start new'));
    await tester.pump();
    expect(replies, [const FeedbackReply(key: 's', actionId: 'startNew')]);
  });

  testWidgets('clear hides the snackbar', (tester) async {
    await pump(tester);
    show(const FeedbackMessage(key: 'a', text: 'Gone'));
    await tester.pumpAndSettle();
    container.read(feedbackControllerProvider.notifier).clear();
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  test('openSheetCountProvider counts and never goes below 0', () {
    final c = ProviderContainer.test();
    c.read(openSheetCountProvider.notifier)
      ..inc()
      ..dec()
      ..dec();
    expect(c.read(openSheetCountProvider), 0);
  });

  testWidgets('B6: a floating rounded card above the nav bar, two lines max', (
    tester,
  ) async {
    await pump(tester);
    show(
      const FeedbackMessage(key: 'c', text: 'Card', kind: FeedbackKind.success),
    );
    await tester.pumpAndSettle();
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.behavior, SnackBarBehavior.floating);
    expect(bar.backgroundColor, Colors.transparent);
    expect(bar.margin, const EdgeInsets.fromLTRB(16, 0, 16, 12));
    expect(find.byType(SpSnack), findsOneWidget);
    expect(tester.widget<Text>(find.text('Card')).maxLines, 2);
    expect(find.byIcon(AppIcons.success), findsOneWidget);
  });

  testWidgets('B6: tapping the action closes the card', (tester) async {
    await pump(tester);
    show(
      const FeedbackMessage(
        key: 'a',
        text: 'Filled',
        actionLabel: 'View',
        action: OpenLocation('/portfolio'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(container.read(feedbackControllerProvider), isNull);
  });

  testWidgets('B6: the close button dismisses a persistent card', (
    tester,
  ) async {
    await pump(tester);
    show(const FeedbackMessage(key: 'p', text: 'Unknown', persist: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Unknown'), findsNothing);
  });
}
