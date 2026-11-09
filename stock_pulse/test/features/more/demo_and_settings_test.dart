import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/more/di/demo_providers.dart';
import 'package:stock_pulse/features/more/di/settings_providers.dart';
import 'package:stock_pulse/features/orders/di/risk_notice_providers.dart';

import '../../helpers/fake_analytics_sink.dart';
import '../../helpers/fake_crash_reporter.dart';
import '../../helpers/fake_debug_client.dart';
import '../../helpers/fake_local_prefs.dart';
import '../../helpers/fake_market_repository.dart';
import '../../helpers/fake_snapshot_store.dart';

void main() {
  late FakeDebugClient debug;
  late FakeLocalPrefs prefs;
  late FakeSnapshotStore store;
  late FakeAnalyticsSink sink;
  late ProviderContainer c;
  var marketBuilds = 0;

  setUp(() {
    debug = FakeDebugClient();
    prefs = FakeLocalPrefs(
      LocalPrefsData.defaults.copyWith(
        analyticsConsent: true,
        riskNoticeAcked: true,
      ),
    );
    store = FakeSnapshotStore();
    sink = FakeAnalyticsSink();
    marketBuilds = 0;
    c = ProviderContainer.test(
      overrides: [
        debugClientProvider.overrideWithValue(debug),
        localPrefsProvider.overrideWith((ref) async => prefs),
        snapshotStoreProvider.overrideWithValue(store),
        analyticsSinksProvider.overrideWithValue([sink]),
        crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        marketRepositoryProvider.overrideWith((ref) {
          marketBuilds++;
          return FakeMarketRepository();
        }),
      ],
    );
    c.listen(demoControllerProvider, (_, _) {});
  });

  group('DemoController', () {
    test('setClock reports success and failure', () async {
      final demo = c.read(demoControllerProvider.notifier);
      final at = DateTime.utc(2026, 11, 10, 4);
      await demo.setClock(at);
      expect(debug.clocks, [at]);
      expect(c.read(demoControllerProvider), const AsyncData<void>(null));

      debug.result = const Failure(NetworkError());
      await demo.setClock(at);
      expect(c.read(demoControllerProvider).error, isA<NetworkError>());
    });

    test('reset clears prefs, cache and analytics, then rebuilds the '
        'repositories', () async {
      expect(await c.read(riskNoticeProvider.future), isTrue);

      c.read(marketRepositoryProvider);
      await c.read(demoControllerProvider.notifier).reset();
      expect(debug.resets, [null]);
      expect(prefs.clears, 1);
      expect(store.clears, 1);
      expect(sink.resets, 1);
      expect(await c.read(riskNoticeProvider.future), isFalse);
      c.read(marketRepositoryProvider);
      expect(marketBuilds, 2);
      expect(c.read(demoControllerProvider).hasError, isFalse);
    });

    test('a failed reset keeps local data', () async {
      debug.result = const Failure(NetworkError());
      await c.read(demoControllerProvider.notifier).reset();
      expect(c.read(demoControllerProvider).hasError, isTrue);
      expect(prefs.clears, 0);
      expect(store.clears, 0);
    });

    test('a result after dispose changes nothing', () async {
      final demo = c.read(demoControllerProvider.notifier);
      debug.gate = Completer();
      final clock = demo.setClock(DateTime.utc(2026));
      final reset = demo.reset();
      c.dispose();
      debug.gate!.complete();
      await clock;
      await reset;
      expect(prefs.clears, 0);
    });
  });

  group('SettingsController', () {
    test('loads prefs and saves the haptics switch', () async {
      expect(
        (await c.read(settingsControllerProvider.future)).hapticsEnabled,
        LocalPrefsData.defaults.hapticsEnabled,
      );
      await c
          .read(settingsControllerProvider.notifier)
          .setHaptics(enabled: false);
      expect(prefs.data.hapticsEnabled, isFalse);
      expect(c.read(settingsControllerProvider).value?.hapticsEnabled, false);
    });

    test('turning analytics off also resets the sinks', () async {
      await c.read(settingsControllerProvider.future);
      final settings = c.read(settingsControllerProvider.notifier);
      await settings.setAnalytics(enabled: true);
      expect(sink.resets, 0);
      await settings.setAnalytics(enabled: false);
      expect(prefs.data.analyticsConsent, isFalse);
      expect(sink.resets, 1);
    });

    test('consent gates events immediately and can be enabled again', () async {
      await c.read(localPrefsProvider.future);
      final analytics = c.read(analyticsProvider);
      final settings = c.read(settingsControllerProvider.notifier);

      analytics.log(Events.screenView('watchlist'));
      await Future<void>.delayed(Duration.zero);
      expect(sink.events, [Events.screenView('watchlist')]);

      await settings.setAnalytics(enabled: false);
      analytics.log(Events.screenView('portfolio'));
      await Future<void>.delayed(Duration.zero);
      expect(sink.events, hasLength(1));

      await settings.setAnalytics(enabled: true);
      analytics.log(Events.screenView('portfolio'));
      await Future<void>.delayed(Duration.zero);
      expect(sink.events, hasLength(2));
    });
  });
}
