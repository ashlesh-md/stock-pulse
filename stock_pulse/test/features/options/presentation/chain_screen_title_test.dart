import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/options/application/chain_controller.dart';
import 'package:stock_pulse/features/options/application/chain_state.dart';
import 'package:stock_pulse/features/options/di/options_providers.dart';
import 'package:stock_pulse/features/options/presentation/screens/chain_screen.dart';

import '../../../helpers/fake_local_prefs.dart';

class _ChainController extends ChainController {
  _ChainController(String underlying)
    : super((underlying: underlying, expiry: null));

  @override
  Future<ChainState> build() async =>
      const ChainState(expiries: [], expiry: '', view: null);
}

void main() {
  testWidgets('chain title stays left-aligned beside connection status', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/options?u=NIFTY',
      routes: [
        GoRoute(
          path: OptionChainRoute.path,
          builder: (_, state) {
            final route = OptionChainRoute.fromState(state);
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
          chainControllerProvider((underlying: 'NIFTY', expiry: null))
              .overrideWith(() => _ChainController('NIFTY')),
          chainControllerProvider((underlying: 'RELIANCE', expiry: null))
              .overrideWith(() => _ChainController('RELIANCE')),
          localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
          networkStatusProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.getTopLeft(find.text('NIFTY options'));
    expect(title.dx, lessThan(40));
    expect(tester.widget<AppBar>(find.byType(AppBar)).centerTitle, isFalse);
    await tester.tap(find.byTooltip('Choose underlying'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RELIANCE'));
    await tester.pumpAndSettle();
    expect(find.text('RELIANCE options'), findsOneWidget);
  });
}
