import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/features/alerts/application/alert_queue.dart';
import 'package:stock_pulse/features/alerts/di/alert_queue_providers.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';
import 'package:stock_pulse/features/alerts/presentation/screens/alerts_screen.dart';
import 'package:stock_pulse/features/more/presentation/screens/add_funds_screen.dart';
import 'package:stock_pulse/features/more/presentation/screens/debug_clock_screen.dart';
import 'package:stock_pulse/features/more/presentation/screens/more_screen.dart';
import 'package:stock_pulse/features/more/presentation/screens/socket_lab_screen.dart';

import '../../app/app_harness.dart';
import '../../helpers/sp_app.dart';

void main() {
  late AppHarness h;
  setUp(() => h = AppHarness());

  Future<void> openMore(WidgetTester tester) async {
    await h.pumpPhone(tester);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.pageBack();
    await tester.pumpAndSettle();
  }

  testWidgets('every More row opens its screen', (tester) async {
    await openMore(tester);
    expect(find.text('Developer'), findsOneWidget);
    for (final (label, screen) in [
      ('Price alerts', AlertsScreen),
      ('Demo clock', DebugClockScreen),
      ('Add funds', AddFundsScreen),
      ('Socket Lab', SocketLabScreen),
    ]) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget, reason: label);
      await back(tester);
    }
  });

  testWidgets('More shows an accessible badge while an alert is triggered', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        const MoreScreen(),
        overrides: [alertQueueProvider.overrideWith(_TriggeredAlertQueue.new)],
      ),
    );

    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .any(
            (semantics) =>
                semantics.properties.label == 'Triggered price alert',
          ),
      isTrue,
    );
  });

  testWidgets('the settings switches save to prefs', (tester) async {
    await openMore(tester);
    final haptics = h.prefs.data.hapticsEnabled;
    final hapticsSwitch = find.ancestor(
      of: find.text('Order vibration feedback'),
      matching: find.byType(SwitchListTile),
    );
    await tester.tap(hapticsSwitch);
    await tester.pumpAndSettle();
    expect(h.prefs.data.hapticsEnabled, !haptics);
    final consent = h.prefs.data.analyticsConsent;
    final analyticsSwitch = find.ancestor(
      of: find.text('Share anonymous usage events'),
      matching: find.byType(SwitchListTile),
    );
    await tester.tap(analyticsSwitch);
    await tester.pumpAndSettle();
    expect(h.prefs.data.analyticsConsent, !consent);
  });

  testWidgets('performance overlay switch displays frame timings', (
    tester,
  ) async {
    await openMore(tester);
    expect(find.textContaining('FPS'), findsNothing);
    await tester.tap(find.text('Show performance overlay'));
    await tester.pump();
    expect(find.textContaining('FPS'), findsOneWidget);
  });

  testWidgets('debug clock: a later time jumps; an earlier one resets only '
      'after confirming', (tester) async {
    h.networkStatusOverride = NetworkStatus.live;
    await openMore(tester);
    await tester.tap(find.text('Demo clock'));
    await tester.pumpAndSettle();
    final tiles = find.byType(ListTile);
    expect(tiles, findsNWidgets(4));

    await tester.tap(tiles.at(2));
    await tester.pumpAndSettle();
    expect(h.debug.clocks, [DateTime.utc(2026, 11, 10, 9, 49, 50)]);

    await tester.tap(tiles.last);
    await tester.pumpAndSettle();
    expect(h.debug.clocks, [
      DateTime.utc(2026, 11, 10, 9, 49, 50),
      DateTime.utc(2026, 11, 10, 10),
    ]);

    await tester.tap(tiles.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.debug.resets, isEmpty);

    await tester.tap(tiles.first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reset demo account'));
    await tester.pumpAndSettle();
    expect(h.debug.resets, [DateTime.utc(2026, 11, 10, 3, 44, 50)]);
  });

  testWidgets('debug clock shows a failed jump', (tester) async {
    h.debug.result = const Failure(NetworkError());
    await openMore(tester);
    await tester.tap(find.text('Demo clock'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not update the demo'), findsOneWidget);
    expect(h.debug.clocks, hasLength(1));
  });

  testWidgets('offline debug clock disables reset and shows Needs connection', (
    tester,
  ) async {
    h.networkStatusOverride = NetworkStatus.offline;
    await openMore(tester);
    await tester.tap(find.text('Demo clock'));
    await tester.pumpAndSettle();

    expect(find.text('Needs connection'), findsOneWidget);
    final clockRows = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .where(
          (tile) =>
              tile.title is Text &&
              (tile.title! as Text).data != 'Needs connection',
        );
    expect(clockRows, hasLength(4));
    expect(clockRows.every((tile) => !tile.enabled), isTrue);
    await tester.tap(find.byType(ListTile).last);
    await tester.pumpAndSettle();
    expect(h.debug.clocks, isEmpty);
    expect(h.debug.resets, isEmpty);
  });
}

class _TriggeredAlertQueue extends AlertQueue {
  @override
  List<PriceAlert> build() => [
    PriceAlert(
      alertId: 'alert-1',
      symbol: 'TCS',
      cond: AlertCondition.above,
      level: 3500,
      status: AlertStatus.triggered,
      createdAt: DateTime.utc(2026),
    ),
  ];
}
