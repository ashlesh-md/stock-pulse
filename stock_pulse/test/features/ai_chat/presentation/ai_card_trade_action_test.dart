import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_view.dart';
import 'package:stock_pulse/features/orders/domain/order_ticket_args.dart'
    show OrderSource;

import '../../../helpers/fake_crash_reporter.dart';

void main() {
  testWidgets('trade opens a one-lot AI ticket without placing it', (
    tester,
  ) async {
    const id = 'NIFTY-261109-24500-CE';
    final router = GoRouter(
      initialLocation: '/ai',
      routes: [
        GoRoute(
          path: '/ai',
          builder: (context, state) => Scaffold(
            body: AiCardView(
              card: AiCard(
                id: 'trade-default-1',
                type: 'quote',
                title: 'NIFTY option',
                fallbackText: '',
                actions: [
                  AiAction('trade', 'Trade this strike', {
                    'instrumentId': id,
                    'side': 'buy',
                  }),
                ],
              ),
              onExplain: (_) {},
            ),
          ),
        ),
        GoRoute(path: '/order/:id', builder: (_, _) => const SizedBox.shrink()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsProvider.overrideWithValue(
            AnalyticsService(
              const [],
              FakeCrashReporter(),
              consent: () => true,
            ),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trade this strike'));
    await tester.pumpAndSettle();
    final route = AppRoute.fromUri(router.state.uri)! as OrderTicketRoute;
    expect(route.args.instrumentId, id);
    expect(route.args.lots, 1);
    expect(route.args.limitPrice, isNull);
    expect(route.args.source, OrderSource.ai);
  });
}
