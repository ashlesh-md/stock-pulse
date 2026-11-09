import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/bootstrap.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/router/app_shell_scaffold.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/push/data/noop_push_service.dart';
import 'package:stock_pulse/core/push/di/push_providers.dart';
import 'package:stock_pulse/core/push/domain/push_service.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';

import '../helpers/fake_analytics_sink.dart';
import '../helpers/fake_crash_reporter.dart';
import '../helpers/fake_debug_client.dart';
import '../helpers/fake_local_prefs.dart';
import '../helpers/fake_market_repository.dart';
import '../helpers/fake_market_socket.dart';
import '../helpers/fake_snapshot_store.dart';

/// The real app (router, shell, hosts) over fakes, with a pending snapshot.
class AppHarness {
  final socket = FakeMarketSocket();
  final reporter = FakeCrashReporter();
  final analyticsSink = FakeAnalyticsSink();
  final snapshot = Completer<AppSnapshot?>();
  final prefs = FakeLocalPrefs();
  final debug = FakeDebugClient();
  MarketRepository marketRepository = FakeMarketRepository();
  PushService pushService = const NoopPushService();
  bool prefsUnavailable = false;
  NetworkStatus? networkStatusOverride;

  /// 10:30 IST on a Tuesday.
  final clock = FakeClock(DateTime.utc(2026, 11, 10, 5));

  Widget app() => appScope(
    reporter: reporter,
    snapshot: snapshot.future,
    overrides: [
      marketSocketProvider.overrideWithValue(socket),
      marketRepositoryProvider.overrideWithValue(marketRepository),
      snapshotStoreProvider.overrideWithValue(FakeSnapshotStore()),
      localPrefsProvider.overrideWith((ref) async {
        if (prefsUnavailable) throw StateError('preferences unavailable');
        return prefs;
      }),
      debugClientProvider.overrideWithValue(debug),
      clockProvider.overrideWithValue(clock),
      pushServiceProvider.overrideWithValue(pushService),
      analyticsSinksProvider.overrideWithValue([analyticsSink]),
      if (networkStatusOverride case final status?)
        networkStatusProvider.overrideWith((ref) => Stream.value(status)),
    ],
  );

  /// Pumps [app] on a phone-sized view, where the shell uses a bottom bar;
  /// the default 800 px test view is medium and gets a rail.
  Future<void> pumpPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app());
  }

  ProviderContainer container(WidgetTester tester) => ProviderScope.containerOf(
    tester.element(find.byType(AppShellScaffold, skipOffstage: false)),
  );

  GoRouter router(WidgetTester tester) =>
      container(tester).read(goRouterProvider);
}
