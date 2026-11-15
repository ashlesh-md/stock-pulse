import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/market_time/domain/clock.dart';
import 'package:stock_pulse/core/market_time/domain/market_clock_state.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/widgets/stale_badge.dart';
import 'package:stock_pulse/features/chart/presentation/chart_stale_badge.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

import '../../../helpers/chart_test_market.dart';
import '../../../helpers/fake_crash_reporter.dart';
import '../../../helpers/sp_app.dart';

void main() {
  testWidgets(
    'chart freshness waits for a quote, then distinguishes live and stale timestamps',
    (tester) async {
      final now = DateTime.utc(2026, 11, 12);
      final repo = CountingMarket();
      await tester.pumpWidget(
        spApp(
          const ChartStaleBadge(instrumentId: 'TCS'),
          overrides: [
            marketRepositoryProvider.overrideWithValue(repo),
            clockProvider.overrideWithValue(FakeClock(now)),
            marketClockProvider.overrideWith(
              (ref) => Stream.value(
                MarketClockState.fallback.copyWith(phase: MarketPhase.open),
              ),
            ),
            networkStatusProvider.overrideWith(
              (ref) => Stream.value(NetworkStatus.live),
            ),
            analyticsProvider.overrideWithValue(
              AnalyticsService(
                const [],
                FakeCrashReporter(),
                consent: () => true,
              ),
            ),
          ],
        ),
      );
      expect(find.byType(StaleBadge), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(StaleBadge), findsNothing);
      repo.push([
        Quote(
          symbol: 'TCS',
          ltp: 100,
          change: 0,
          changePercent: 0,
          lastTradeTime: now.subtract(const Duration(seconds: 10)),
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(StaleBadge), findsOneWidget);
    },
  );
}
