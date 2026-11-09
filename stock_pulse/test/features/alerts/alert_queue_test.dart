import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/alert_banner_host.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/storage/domain/local_prefs.dart';
import 'package:stock_pulse/features/alerts/di/alert_queue_providers.dart';
import 'package:stock_pulse/features/alerts/di/alerts_data_providers.dart';
import 'package:stock_pulse/features/alerts/domain/alerts_repository.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';

import '../../helpers/fake_local_prefs.dart';
import '../../helpers/sp_app.dart';

class _Alerts implements AlertsRepository {
  _Alerts(this.stream);

  final StreamController<PriceAlert> stream;
  @override
  Stream<PriceAlert> get triggered => stream.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PriceAlert _alert(String id, {String symbol = 'TCS'}) => PriceAlert(
  alertId: id,
  symbol: symbol,
  cond: AlertCondition.above,
  level: 3500,
  status: AlertStatus.triggered,
  createdAt: DateTime.utc(2026),
  triggerLtp: 3510,
);

void main() {
  test(
    'trigger queue deduplicates stream repeats and persisted seen ids',
    () async {
      final stream = StreamController<PriceAlert>.broadcast();
      final alerts = _Alerts(stream);
      final prefs = FakeLocalPrefs(
        LocalPrefsData.defaults.copyWith(seenAlertIds: const {'seen'}),
      );
      final container = ProviderContainer.test(
        overrides: [
          alertsRepositoryProvider.overrideWithValue(alerts),
          localPrefsProvider.overrideWith((_) async => prefs),
        ],
      );
      container.listen(alertQueueProvider, (_, _) {});

      alerts.stream
        ..add(_alert('seen'))
        ..add(_alert('new'))
        ..add(_alert('new'));
      await pumpEventQueue();
      expect(container.read(alertQueueProvider), [_alert('new')]);
      expect(prefs.data.seenAlertIds, {'seen', 'new'});

      container.read(alertQueueProvider.notifier).dismiss();
      expect(container.read(alertQueueProvider), isEmpty);
      await stream.close();
    },
  );

  testWidgets('alert banner waits for an open sheet and dismisses', (
    tester,
  ) async {
    final stream = StreamController<PriceAlert>.broadcast();
    final alerts = _Alerts(stream);
    final prefs = FakeLocalPrefs();
    await tester.pumpWidget(
      spApp(
        const AlertBannerHost(child: Text('Alerts page')),
        overrides: [
          alertsRepositoryProvider.overrideWithValue(alerts),
          localPrefsProvider.overrideWith((_) async => prefs),
        ],
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AlertBannerHost)),
    );
    alerts.stream.add(_alert('a1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TCS reached ₹3,510.00'), findsOneWidget);

    container.read(openSheetCountProvider.notifier).inc();
    await tester.pump();
    expect(find.text('TCS reached ₹3,510.00'), findsNothing);
    container.read(openSheetCountProvider.notifier).dec();
    await tester.pump();
    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(find.text('TCS reached ₹3,510.00'), findsNothing);
    await stream.close();
  });
}
