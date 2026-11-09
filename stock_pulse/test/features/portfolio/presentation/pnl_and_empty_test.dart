import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_controller.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_funds_provider.dart';
import 'package:stock_pulse/features/portfolio/application/portfolio_state.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_section.dart';
import 'package:stock_pulse/features/portfolio/presentation/screens/portfolio_screen.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/pnl_card.dart';

class _Empty extends PortfolioController {
  @override
  Future<PortfolioState> build() async =>
      const PortfolioState(orders: [], positions: []);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadHoldings() async {}
}

void main() {
  group('pnlText', () {
    test('B14: zero and sub-paisa totals read as a neutral ₹0.00', () {
      expect(pnlText(0), '₹0.00');
      expect(pnlText(-0.004), '₹0.00');
      expect(pnlText(0.004), '₹0.00');
    });

    test('B14: gains and losses carry a sign before the rupee', () {
      expect(pnlText(12.345), '+₹12.35');
      expect(pnlText(-4.1), '−₹4.10');
      expect(pnlText(150000), '+₹1,50,000.00');
    });
  });

  Widget app(PortfolioSection section, List<String> visited) {
    final router = GoRouter(
      initialLocation: '/portfolio',
      routes: [
        GoRoute(
          path: '/portfolio',
          builder: (_, _) => PortfolioScreen(initialSection: section),
        ),
        GoRoute(
          path: '/watchlist',
          builder: (_, state) {
            visited.add(state.uri.path);
            return const SizedBox();
          },
        ),
      ],
    );
    return ProviderScope(
      retry: (_, _) => null,
      overrides: [
        portfolioControllerProvider.overrideWith(_Empty.new),
        portfolioFundsProvider.overrideWith((ref) => const Stream.empty()),
        networkStatusProvider.overrideWith((ref) => const Stream.empty()),
      ],
      child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
    );
  }

  testWidgets('B14: an empty P&L card shows ₹0.00, never +0.00', (
    tester,
  ) async {
    await tester.pumpWidget(app(PortfolioSection.positions, []));
    await tester.pumpAndSettle();
    expect(find.text('₹0.00'), findsNWidgets(2));
    expect(find.text('+0.00'), findsNothing);
  });

  for (final section in [
    PortfolioSection.positions,
    PortfolioSection.holdings,
  ]) {
    testWidgets('B14: empty ${section.name} offer Go to watchlist', (
      tester,
    ) async {
      final visited = <String>[];
      await tester.pumpWidget(app(section, visited));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Go to watchlist'));
      await tester.pumpAndSettle();
      expect(visited, ['/watchlist']);
    });
  }
}
