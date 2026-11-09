import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/alerts/di/alerts_data_providers.dart';
import 'package:stock_pulse/features/alerts/di/alerts_providers.dart';
import 'package:stock_pulse/features/alerts/domain/alerts_repository.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';

import '../../helpers/fake_crash_reporter.dart';

class Repo extends Mock implements AlertsRepository {}

void main() {
  test(
    'valid creation appears immediately, bad input and failures preserve list',
    () async {
      final repo = Repo();
      final updates = StreamController<List<PriceAlert>>();
      addTearDown(updates.close);
      when(repo.watchAll).thenAnswer((_) => updates.stream);
      final alert = PriceAlert(
        alertId: 'a1',
        symbol: 'TCS',
        cond: AlertCondition.above,
        level: 100,
        status: AlertStatus.active,
        createdAt: DateTime.utc(2026),
      );
      when(() => repo.create('TCS', AlertCondition.above, 100))
          .thenAnswer((_) async => Success(alert));
      when(() => repo.delete('a1'))
          .thenAnswer((_) async => const Failure(NetworkError()));
      final c = ProviderContainer(
        overrides: [
          alertsRepositoryProvider.overrideWithValue(repo),
          crashReporterProvider.overrideWithValue(FakeCrashReporter()),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(alertsControllerProvider, (_, _) {});
      addTearDown(sub.close);
      updates.add([]);
      await c.read(alertsControllerProvider.future);
      final controller = c.read(alertsControllerProvider.notifier);
      expect(await controller.create('', AlertCondition.above, 100), isFalse);
      expect(
        await controller.create('TCS', AlertCondition.above, double.nan),
        isFalse,
      );
      expect(await controller.create('TCS', AlertCondition.above, 100), isTrue);
      expect(c.read(alertsControllerProvider).requireValue, [alert]);
      expect(await controller.cancel('a1'), isFalse);
      expect(c.read(alertsControllerProvider).requireValue, [alert]);
    },
  );
}
