import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/push/di/push_providers.dart';
import 'package:stock_pulse/core/push/domain/push_permission_service.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/alerts/di/alerts_data_providers.dart';
import 'package:stock_pulse/features/alerts/domain/alerts_repository.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';
import 'package:stock_pulse/features/alerts/presentation/screens/alerts_screen.dart';

import '../../helpers/fake_crash_reporter.dart';
import '../../helpers/fake_local_prefs.dart';

class _Repository extends Mock implements AlertsRepository {}

class _Permissions implements PushPermissionService {
  PushPermissionStatus value = PushPermissionStatus.notDetermined;
  int requests = 0;
  int settingsOpens = 0;

  @override
  Future<PushPermissionStatus> status() async => value;
  @override
  Future<PushPermissionStatus> request() async {
    requests++;
    value = PushPermissionStatus.denied;
    return value;
  }

  @override
  Future<void> openSettings() async => settingsOpens++;
}

PriceAlert _alert({
  String id = 'a1',
  String symbol = 'TCS',
  AlertStatus status = AlertStatus.active,
  AlertCondition condition = AlertCondition.above,
}) => PriceAlert(
  alertId: id,
  symbol: symbol,
  cond: condition,
  level: 3100,
  status: status,
  createdAt: DateTime.utc(2026),
);

void main() {
  late _Repository repository;
  late FakeLocalPrefs prefs;
  late _Permissions permissions;

  setUp(() {
    repository = _Repository();
    prefs = FakeLocalPrefs();
    permissions = _Permissions();
    when(repository.watchAll).thenAnswer((_) => Stream.value(const []));
  });

  Widget app() => ProviderScope(
    retry: (_, _) => null,
    overrides: [
      alertsRepositoryProvider.overrideWithValue(repository),
      localPrefsProvider.overrideWith((ref) async => prefs),
      pushPermissionServiceProvider.overrideWithValue(permissions),
      crashReporterProvider.overrideWithValue(FakeCrashReporter()),
      analyticsProvider.overrideWithValue(
        AnalyticsService([], FakeCrashReporter(), consent: () => false),
      ),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: const AlertsScreen()),
  );

  testWidgets('empty screen opens form, validates, and creates below alert', (
    tester,
  ) async {
    when(
      () => repository.create('TCS', AlertCondition.below, 3100),
    ).thenAnswer((_) async => Success(_alert(condition: AlertCondition.below)));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(
      find.text('No price alerts. Create one to follow a price.'),
      findsOneWidget,
    );

    expect(find.byTooltip('Create alert'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Create alert').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create alert').last);
    await tester.pump();
    expect(
      find.text('Enter an instrument and a finite price greater than zero'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(0), ' TCS ');
    await tester.enterText(find.byType(TextField).at(1), '3100');
    await tester.tap(find.text('Below'));
    await tester.pump();
    await tester.tap(find.text('Create alert').last);
    await tester.pumpAndSettle();
    expect(find.text('Price alert notifications'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(permissions.requests, 0);
    expect(prefs.data.notificationExplainerShown, isTrue);

    verify(() => repository.create('TCS', AlertCondition.below, 3100))
        .called(1);
    expect(find.text('TCS'), findsOneWidget);
    expect(find.textContaining('Below'), findsOneWidget);
  });

  testWidgets('cancelled rows show status; active rows can be cancelled', (
    tester,
  ) async {
    final cancelled = _alert(id: 'a2', status: AlertStatus.cancelled);
    when(repository.watchAll).thenAnswer(
      (_) => Stream.value([
        _alert(),
        _alert(id: 'a2', symbol: 'INFY', status: AlertStatus.triggered),
      ]),
    );
    when(() => repository.delete('a1'))
        .thenAnswer((_) async => Success(cancelled));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('TCS'), findsOneWidget);
    expect(find.text('triggered'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancel alert'));
    await tester.pumpAndSettle();

    verify(() => repository.delete('a1')).called(1);
    expect(find.text('cancelled'), findsOneWidget);
  });

  testWidgets(
    'first successful alert can request once; later alerts do not ask',
    (tester) async {
      when(() => repository.create('TCS', AlertCondition.above, 3100))
          .thenAnswer((_) async => Success(_alert()));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create alert').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'TCS');
      await tester.enterText(find.byType(TextField).at(1), '3100');
      await tester.tap(find.text('Create alert').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enable notifications'));
      await tester.pumpAndSettle();
      expect(permissions.requests, 1);
      expect(prefs.data.notificationExplainerShown, isTrue);

      await tester.tap(find.byTooltip('Create alert'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'TCS');
      await tester.enterText(find.byType(TextField).at(1), '3100');
      await tester.tap(find.text('Create alert').last);
      await tester.pumpAndSettle();
      expect(find.text('Price alert notifications'), findsNothing);
      expect(permissions.requests, 1);
    },
  );

  testWidgets('failed creation keeps form open with a message', (tester) async {
    when(() => repository.create('TCS', AlertCondition.above, 3100))
        .thenAnswer((_) async => const Failure(NetworkError()));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create alert').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'TCS');
    await tester.enterText(find.byType(TextField).at(1), '3100');
    await tester.tap(find.text('Create alert').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Could not update the alert. Please retry.'),
      findsOneWidget,
    );
  });

  testWidgets('error state retries loading alerts', (tester) async {
    var reads = 0;
    when(repository.watchAll).thenAnswer((_) {
      reads++;
      return reads == 1
          ? Stream.error(StateError('offline'))
          : Stream.value([_alert()]);
    });

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('TCS'), findsOneWidget);
    expect(reads, 2);
  });
}
