import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/alert_banner_host.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/alerts/application/alert_queue.dart';
import 'package:stock_pulse/features/alerts/di/alert_queue_providers.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';

import '../helpers/fake_analytics_sink.dart';
import '../helpers/fake_crash_reporter.dart';

void main() {
  late GoRouter router;
  setUp(() {
    router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const _TopInset()),
        GoRoute(
          path: '/stock/:id',
          builder: (_, s) => Text('stock ${s.pathParameters['id']}'),
        ),
      ],
    );
  });
  tearDown(() => router.dispose());

  Widget app({bool seeded = true, FakeAnalyticsSink? analyticsSink}) =>
      ProviderScope(
        overrides: [
          goRouterProvider.overrideWithValue(router),
          if (seeded) alertQueueProvider.overrideWith(_SeededQueue.new),
          if (analyticsSink != null)
            analyticsProvider.overrideWithValue(
              AnalyticsService(
                [analyticsSink],
                FakeCrashReporter(),
                consent: () => true,
              ),
            ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(padding: const EdgeInsets.only(top: 24)),
            child: AlertBannerHost(child: child!),
          ),
        ),
      );

  testWidgets('shows the first triggered alert and Dismiss removes it', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(find.text('RELIANCE reached ₹1,400.00'), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.textContaining('reached'), findsNothing);
  });

  testWidgets('the child does not get the status-bar inset a second time '
      'while the banner shows', (tester) async {
    await tester.pumpWidget(app());
    expect(find.text('top 0.0'), findsOneWidget);
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.text('top 24.0'), findsOneWidget);
  });

  testWidgets('View dismisses the alert and opens the stock', (tester) async {
    final sink = FakeAnalyticsSink();
    await tester.pumpWidget(app(analyticsSink: sink));
    await tester.tap(find.text('View instrument'));
    await tester.pumpAndSettle();
    expect(find.text('stock RELIANCE'), findsOneWidget);
    expect(find.textContaining('reached'), findsNothing);
    expect(sink.events, hasLength(1));
    expect(sink.events.single.name, 'alert_opened');
    expect(sink.events.single.params, {'source': 'banner'});
  });
}

class _TopInset extends StatelessWidget {
  const _TopInset();

  @override
  Widget build(BuildContext context) =>
      Text('top ${MediaQuery.paddingOf(context).top}');
}

class _SeededQueue extends AlertQueue {
  @override
  List<PriceAlert> build() => [
    PriceAlert(
      alertId: 'al1',
      symbol: 'RELIANCE',
      cond: AlertCondition.above,
      level: 1400,
      status: AlertStatus.triggered,
      createdAt: DateTime.utc(2026),
    ),
  ];
}
