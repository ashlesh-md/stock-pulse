import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stock_pulse/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('watchlist scrolling performance with normal market ticking', (
    tester,
  ) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    final scrollable = find.byType(Scrollable).first;
    await binding.watchPerformance(() async {
      for (var i = 0; i < 8; i++) {
        await tester.drag(scrollable, const Offset(0, -120));
        await tester.pump(const Duration(milliseconds: 16));
      }
    }, reportKey: 'watchlist');
  });
}
