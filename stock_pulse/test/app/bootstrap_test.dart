import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/bootstrap.dart';
import 'package:stock_pulse/app/router/app_shell_scaffold.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/presentation/screens/watchlist_screen.dart';

import '../helpers/fake_market_repository.dart';
import '../helpers/fake_market_socket.dart';
import 'app_harness.dart';

void main() {
  testWidgets('T1 TR-14: one frame paints the shell and watchlist while the '
      'snapshot is still pending', (tester) async {
    final h = AppHarness();

    await h.pumpPhone(tester);

    expect(h.snapshot.isCompleted, isFalse);
    expect(find.byType(AppShellScaffold), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(WatchlistScreen), findsOneWidget);
    expect(h.reporter.errors, isEmpty);
  });

  testWidgets('NFR-1: bootstrap installs the hooks and runs the app without '
      'awaiting the disk', (tester) async {
    final flutterOnError = FlutterError.onError;
    final platformOnError = PlatformDispatcher.instance.onError;
    final print = debugPrint;
    debugPrint = (_, {wrapWidth}) {};

    bootstrap(
      overrides: [
        marketSocketProvider.overrideWithValue(FakeMarketSocket()),
        marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
      ],
    );
    final installed = FlutterError.onError;
    FlutterError.onError = flutterOnError;
    PlatformDispatcher.instance.onError = platformOnError;
    await tester.pump();

    expect(installed, isNot(flutterOnError));
    expect(find.byType(AppShellScaffold), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox());
    debugPrint = print;
  });
}
