import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_section.dart';

void main() {
  testWidgets('fromState reads typed args back from the router state', (
    tester,
  ) async {
    final seen = <AppRoute>[];
    final router = GoRouter(
      initialLocation: '/options?u=NIFTY&e=2026-11-10',
      routes: [
        GoRoute(
          path: OptionChainRoute.path,
          builder: (_, s) {
            seen.add(OptionChainRoute.fromState(s));
            return const SizedBox();
          },
        ),
        GoRoute(
          path: PortfolioRoute.path,
          builder: (_, s) {
            seen.add(PortfolioRoute.fromState(s));
            return const SizedBox();
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    router.go(
      const PortfolioRoute(section: PortfolioSection.holdings).location,
    );
    await tester.pumpAndSettle();

    expect(
      seen.first,
      const OptionChainRoute(underlying: 'NIFTY', expiry: '2026-11-10'),
    );
    expect(seen.last, const PortfolioRoute(section: PortfolioSection.holdings));
  });
}
