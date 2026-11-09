import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/push_link_handler.dart';
import 'package:stock_pulse/app/router/app_router.dart';
import 'package:stock_pulse/app/snapshot/app_snapshot.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/di/l10n_providers.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/push/di/push_providers.dart';
import 'package:stock_pulse/core/storage/application/snapshot_scheduler.dart';
import 'package:stock_pulse/core/storage/data/file_snapshot_store.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/presentation/visibility_route_observer.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/market_repository.dart';
import 'package:stock_pulse/features/orders/di/orders_data_providers.dart';
import 'package:stock_pulse/features/portfolio/di/portfolio_data_providers.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_book.dart';
import 'package:stock_pulse/features/portfolio/domain/portfolio_repository.dart';

/// The snapshot read at startup, `null` when there is none or it was
/// discarded. Overridden in `bootstrap()` with a future started before
/// `runApp`; tests override it (`overrideWith((ref) async => null)`).
final snapshotProvider = FutureProvider<AppSnapshot?>(
  (ref) => throw UnimplementedError(
    'snapshotProvider is overridden in bootstrap(); override it in tests',
  ),
);

class SnapshotRestoration {
  PortfolioBook? cachedBook;
}

final restoreSnapshotProvider = Provider<SnapshotRestoration>((ref) {
  final restoration = SnapshotRestoration();
  final market = ref.watch(marketRepositoryProvider);
  final portfolio = ref.watch(portfolioRepositoryProvider);
  ref.listen(snapshotProvider, (_, next) {
    final snapshot = next.value;
    if (snapshot == null) return;
    market.seedFromCache(snapshot.quotes);
    if (market is CacheSeedableMarket) {
      (market as CacheSeedableMarket).seedInstruments(snapshot.instruments);
    }
    if (portfolio is CacheSeedablePortfolio && portfolio.current == null) {
      (portfolio as CacheSeedablePortfolio).seedFromCache(
        PortfolioBook(
          positions: snapshot.positions,
          holdings: snapshot.holdings,
        ),
      );
      restoration.cachedBook = portfolio.current;
    }
  }, fireImmediately: true);
  return restoration;
});

/// One router per container, disposed with it.
final goRouterProvider = Provider<GoRouter>((ref) {
  final router = buildAppRouter(
    onDeepLinkOpened: (link) {
      ref
          .read(analyticsProvider)
          .log(
            Events.deepLinkOpened(
              link.path,
              link.scheme == 'stockpulse' ? 'custom' : 'universal',
            ),
          );
    },
    onInvalidLink: () {
      ref
          .read(feedbackControllerProvider.notifier)
          .show(
            FeedbackMessage(
              key: 'links.not_available',
              text: ref.read(stringsProvider).common.linkNotAvailable,
            ),
          );
    },
    observers: [
      VisibilityRouteObserver(ref.read(coveredStateProvider.notifier)),
    ],
  );
  String? lastLocation;
  void trackScreen() {
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (path == lastLocation) return;
    lastLocation = path;
    ref.read(analyticsProvider).log(Events.screenView(path));
  }

  router.routerDelegate.addListener(trackScreen);
  DateTime? lastConnectionEventAt;
  ref.listen(networkStatusProvider, (previous, next) {
    final oldStatus = previous?.asData?.value;
    final status = next.asData?.value;
    if (oldStatus == null || status == null || oldStatus == status) return;
    final now = ref.read(clockProvider).now();
    final last = lastConnectionEventAt;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) {
      return;
    }
    lastConnectionEventAt = now;
    ref.read(analyticsProvider).log(Events.connectionChanged(status.name));
  });
  ref.onDispose(() {
    router.routerDelegate.removeListener(trackScreen);
    router.dispose();
  });
  return router;
});

/// Joins core storage to three features, so it lives in the composition
/// root. Builds the snapshot from read-only repository getters, never from
/// screen controllers.
final snapshotSchedulerProvider = Provider<SnapshotScheduler>((ref) {
  final store = ref.watch(snapshotStoreProvider);
  final market = ref.watch(marketRepositoryProvider);
  final portfolio = ref.watch(portfolioRepositoryProvider);
  final clock = ref.watch(clockProvider);
  final serverClock = ref.watch(serverClockProvider);
  final restoration = ref.watch(restoreSnapshotProvider);
  var status = NetworkStatus.reconnecting;
  ref.listen(
    networkStatusProvider,
    (_, next) => status = next.value ?? status,
    fireImmediately: true,
  );

  final scheduler = SnapshotScheduler(
    store: store,
    // A test fake has no flag: then only hide and resync save.
    isDirty: () => store is FileSnapshotStore && store.isDirty,
    capture: () {
      final ids = market.watchlistIds;
      final book = portfolio.current;
      return AppSnapshot(
        savedAt: serverClock.synced ? serverClock.now() : clock.now(),
        watchlistIds: ids,
        quotes: market.latestQuotes(ids),
        instruments: [for (final id in ids) ?market.instrument(id)],
        positions: book?.positions ?? const [],
        holdings: book?.holdings ?? const [],
      );
    },
    hasLiveData: () =>
        portfolio.current != null &&
            !identical(portfolio.current, restoration.cachedBook) ||
        market.latestQuotes(market.watchlistIds).any((q) => !q.fromCache),
    isLive: () => status == NetworkStatus.live,
    resyncCompleted: ref.watch(orderRepositoryProvider).resyncCompleted,
  );
  ref.onDispose(scheduler.dispose);
  return scheduler;
});

final pushLinkHandlerProvider = Provider<PushLinkHandler>((ref) {
  final handler = PushLinkHandler(
    ref.watch(pushServiceProvider),
    ref.watch(goRouterProvider),
    ref.watch(analyticsProvider),
    ref.watch(crashReporterProvider),
    onInvalidLink: () {
      ref
          .read(feedbackControllerProvider.notifier)
          .show(
            FeedbackMessage(
              key: 'links.not_available',
              text: ref.read(stringsProvider).common.linkNotAvailable,
            ),
          );
    },
    alertAlreadySeen: (id) =>
        ref.read(localPrefsProvider).value?.data.seenAlertIds.contains(id) ??
        false,
    onForegroundMessage: (message, path) {
      final strings = ref.read(stringsProvider).alerts;
      ref
          .read(feedbackControllerProvider.notifier)
          .show(
            FeedbackMessage(
              key: 'push.foreground.${message.id}',
              text: message.title ?? strings.triggeredAlert,
              actionLabel: path == null ? null : strings.view,
              action: path == null ? null : OpenLocation(path),
            ),
          );
    },
  );
  ref.onDispose(handler.dispose);
  return handler;
});
