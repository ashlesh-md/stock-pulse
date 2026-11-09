import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/covered_state.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/domain/instrument.dart';

import '../../helpers/fake_local_prefs.dart';
import '../../helpers/fake_market_repository.dart';

void main() {
  test('watchlist keeps its data but releases quotes while hidden', () async {
    final repository = FakeMarketRepository(
      instruments: const [
        Instrument(
          symbol: 'TCS',
          name: 'TCS',
          exchange: 'NSE',
          sector: 'IT',
          tickSize: 0.05,
          lotSize: 1,
        ),
      ],
    );
    final container = ProviderContainer.test(
      overrides: [
        marketRepositoryProvider.overrideWithValue(repository),
        localPrefsProvider.overrideWith((ref) async => FakeLocalPrefs()),
      ],
    );
    final keepAlive = container.listen(watchlistControllerProvider, (_, _) {});
    await container.read(watchlistControllerProvider.future);
    final loaded = container.read(watchlistControllerProvider).requireValue;
    expect(repository.activeWatchers, 1);

    container
        .read(coveredStateProvider.notifier)
        .set(
          const CoveredState(topOpaque: ScreenId.stockDetail, opaqueDepth: 1),
        );
    await container.pump();
    expect(repository.activeWatchers, 0);
    expect(container.read(watchlistControllerProvider).requireValue, loaded);

    container.read(coveredStateProvider.notifier).set(CoveredState.shell);
    await container.pump();
    expect(repository.activeWatchers, 1);

    container
        .read(selectedTabProvider.notifier)
        .mirror(kTabs.indexOf(ScreenId.options));
    await container.pump();
    expect(repository.activeWatchers, 0);
    container
        .read(selectedTabProvider.notifier)
        .mirror(kTabs.indexOf(ScreenId.watchlist));
    await container.pump();
    expect(repository.activeWatchers, 1);
    expect(repository.watchCalls, hasLength(3));
    keepAlive.close();
    await container.pump();
    expect(repository.activeWatchers, 0);
  });
}
