import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/push/di/push_providers.dart';
import 'package:stock_pulse/core/push/domain/push_permission_service.dart';
import 'package:stock_pulse/features/more/presentation/settings/notifications_row.dart';

import '../../helpers/sp_app.dart';

class _Permission implements PushPermissionService {
  _Permission(this.current);
  PushPermissionStatus current;
  int requests = 0;
  int settings = 0;

  @override
  Future<PushPermissionStatus> status() async => current;

  @override
  Future<PushPermissionStatus> request() async {
    requests++;
    return current = PushPermissionStatus.granted;
  }

  @override
  Future<void> openSettings() async => settings++;
}

void main() {
  Future<_Permission> pump(WidgetTester tester, PushPermissionStatus s) async {
    final permission = _Permission(s);
    await tester.pumpWidget(
      spApp(
        NotificationsRow(key: UniqueKey()),
        overrides: [
          pushPermissionServiceProvider.overrideWithValue(permission),
        ],
      ),
    );
    await tester.pumpAndSettle();
    return permission;
  }

  testWidgets('not asked yet: a tap asks, then shows it on', (tester) async {
    final p = await pump(tester, PushPermissionStatus.notDetermined);
    expect(find.text('Notifications off'), findsOneWidget);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(p.requests, 1);
    expect(find.text('Notifications off'), findsNothing);
  });

  testWidgets('denied: a tap opens the system settings', (tester) async {
    final p = await pump(tester, PushPermissionStatus.denied);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect((p.requests, p.settings), (0, 1));
  });

  testWidgets('granted: a tap changes nothing', (tester) async {
    final p = await pump(tester, PushPermissionStatus.granted);
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect((p.requests, p.settings), (0, 0));
  });
}
