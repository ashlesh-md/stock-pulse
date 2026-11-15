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
import 'package:stock_pulse/core/l10n/app_strings.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/push/data/noop_push_service.dart';
import 'package:stock_pulse/core/push/di/push_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';
import 'package:stock_pulse/features/ai_chat/di/ai_chat_data_providers.dart';
import 'package:stock_pulse/features/chart/di/chart_data_providers.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/options/di/options_data_providers.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_providers.dart';

import '../helpers/fake_analytics_sink.dart';
import '../helpers/fake_crash_reporter.dart';
import '../helpers/fake_debug_client.dart';
import '../helpers/fake_local_prefs.dart';
import '../helpers/fake_market_socket.dart';
import '../helpers/fake_pending_order_store.dart';
import '../helpers/fake_snapshot_store.dart';
import 'pseudo_fakes.dart';

/// The real app over fakes with data on every main screen, shown in the
/// pseudo-locale at [width] × 800 dp and [textScale].
class PseudoApp {
  PseudoApp({required this.width, required this.textScale, this.pseudo = true});

  final double width;
  final double textScale;
  final bool pseudo;

  Widget _app() => appScope(
    reporter: FakeCrashReporter(),
    snapshot: Completer<AppSnapshot?>().future,
    overrides: [
      marketSocketProvider.overrideWithValue(FakeMarketSocket()),
      chartDirectoryProvider.overrideWithValue(null),
      marketRepositoryProvider.overrideWithValue(pseudoMarket()),
      chainRepositoryProvider.overrideWithValue(PseudoChainRepository()),
      portfolioRepositoryProvider.overrideWithValue(
        PseudoPortfolioRepository(),
      ),
      orderRepositoryProvider.overrideWithValue(PseudoOrderRepository()),
      fakePendingOrderStoreOverride(),
      chatHistoryProvider.overrideWithValue(PseudoChatHistory()),
      networkStatusProvider.overrideWith(
        (ref) => Stream.value(NetworkStatus.live),
      ),
      portfolioControllerProvider.overrideWith(PseudoPortfolioController.new),
      snapshotStoreProvider.overrideWithValue(FakeSnapshotStore()),
      localPrefsProvider.overrideWith(
        (ref) async => FakeLocalPrefs(
          LocalPrefsData.defaults.copyWith(riskNoticeAcked: true),
        ),
      ),
      debugClientProvider.overrideWithValue(FakeDebugClient()),
      clockProvider.overrideWithValue(FakeClock(pseudoNow)),
      pushServiceProvider.overrideWithValue(const NoopPushService()),
      analyticsSinksProvider.overrideWithValue([FakeAnalyticsSink()]),
    ],
  );

  Future<void> pump(WidgetTester tester) async {
    final dispatcher = tester.platformDispatcher;
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    final locale = pseudo ? pseudoLocale : defaultLocale;
    dispatcher.localeTestValue = locale;
    dispatcher.localesTestValue = [locale];
    dispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(dispatcher.clearLocaleTestValue);
    addTearDown(dispatcher.clearLocalesTestValue);
    addTearDown(dispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
  }

  Future<void> go(WidgetTester tester, String location) async {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShellScaffold, skipOffstage: false)),
    );
    container.read<GoRouter>(goRouterProvider).go(location);
    await tester.pumpAndSettle();
  }
}
