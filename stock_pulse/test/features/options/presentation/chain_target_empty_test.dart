import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/options/presentation/screens/chain_screen.dart';

import '../../../helpers/fake_local_prefs.dart';

void main() {
  testWidgets('an unselected options root asks for an underlying', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: OptionChainRoute.path,
      routes: [
        GoRoute(
          path: OptionChainRoute.path,
          builder: (_, state) {
            final route = OptionChainRoute.fromState(state);
            if (route.underlying == 'RELIANCE') {
              return const Text('RELIANCE selected');
            }
            return ChainScreen(
              underlying: route.underlying,
              expiry: route.expiry,
            );
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Choose underlying'), findsNWidgets(2));
    expect(find.text('NIFTY options'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('NIFTY'), findsOneWidget);
    expect(find.text('RELIANCE'), findsOneWidget);
    expect(find.text('HDFCBANK'), findsOneWidget);
    await tester.tap(find.text('RELIANCE'));
    await tester.pumpAndSettle();
    expect(find.text('RELIANCE selected'), findsOneWidget);
  });
}
