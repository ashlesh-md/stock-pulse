import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/features/market/presentation/widgets/order_summary_card.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/presentation/widgets/option_risk_gate.dart';
import 'package:stock_pulse/features/orders/presentation/widgets/order_nudge_strip.dart';
import 'package:stock_pulse/features/orders/presentation/widgets/order_quantity_field.dart';
import 'package:stock_pulse/features/orders/presentation/widgets/risk_notice_panel.dart';

import '../../../helpers/fake_crash_reporter.dart';
import '../../../helpers/fake_local_prefs.dart';
import '../../../helpers/sp_app.dart';

void main() {
  testWidgets('order summary shows available funds and short-option note', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        const Scaffold(
          body: OrderSummaryCard(
            quantity: 65,
            price: 42,
            product: ProductType.nrml,
            availableFunds: 5000,
            marginNotSimulated: true,
          ),
        ),
      ),
    );

    expect(find.textContaining('Funds available:'), findsOneWidget);
    expect(
      find.text('Margin is not simulated for short options.'),
      findsOneWidget,
    );
    expect(find.text('Estimated margin'), findsNothing);
  });

  testWidgets('risk notice requires acknowledgement before continuing', (
    tester,
  ) async {
    var continued = 0;
    await tester.pumpWidget(
      spApp(Scaffold(body: RiskNoticePanel(onContinue: () => continued++))),
    );
    final button = find.byType(FilledButton);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    expect(continued, 1);
  });

  testWidgets('option risk acknowledgement persists and opens the ticket', (
    tester,
  ) async {
    final prefs = FakeLocalPrefs();
    final overrides = [
      localPrefsProvider.overrideWith((_) async => prefs),
      crashReporterProvider.overrideWithValue(FakeCrashReporter()),
    ];
    await tester.pumpWidget(
      spApp(
        const OptionRiskGate(child: Text('Option ticket')),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Option ticket'), findsNothing);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Option ticket'), findsOneWidget);
    expect(prefs.data.riskNoticeAcked, isTrue);

    await tester.pumpWidget(
      spApp(
        const OptionRiskGate(child: Text('Option ticket')),
        overrides: overrides,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Option ticket'), findsOneWidget);
  });

  testWidgets('quantity step buttons clamp and publish the updated count', (
    tester,
  ) async {
    final controller = TextEditingController(text: '1');
    addTearDown(controller.dispose);
    final changes = <int?>[];
    await tester.pumpWidget(
      spApp(
        Scaffold(
          body: OrderQuantityField(
            controller: controller,
            label: 'Quantity',
            onChanged: changes.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Decrease Quantity'));
    expect(controller.text, '1');
    await tester.tap(find.byTooltip('Increase Quantity'));
    expect(controller.text, '2');
    expect(changes, [1, 2]);
  });

  testWidgets('locked quantity field disables edits and step buttons', (
    tester,
  ) async {
    final controller = TextEditingController(text: '3');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      spApp(
        Scaffold(
          body: OrderQuantityField(
            controller: controller,
            label: 'Lots',
            onChanged: null,
          ),
        ),
      ),
    );

    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(
      tester
          .widgetList<IconButton>(find.byType(IconButton))
          .every((button) => button.onPressed == null),
      isTrue,
    );
  });

  testWidgets('soft order nudges can be dismissed and update with the draft', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(const Scaffold(body: OrderNudgeStrip(messages: ['Price is far']))),
    );
    expect(find.text('Price is far'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Price is far'), findsNothing);
    await tester.pumpWidget(
      spApp(const Scaffold(body: OrderNudgeStrip(messages: ['Expires today']))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Expires today'), findsOneWidget);
  });

  testWidgets(
    'a failed risk-notice read keeps the ticket hidden behind Retry',
    (tester) async {
      var reads = 0;
      await tester.pumpWidget(
        spApp(
          const OptionRiskGate(child: Text('ticket')),
          overrides: [
            localPrefsProvider.overrideWith((_) async {
              reads++;
              throw StateError('disk');
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(reads, greaterThanOrEqualTo(1));
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('ticket'), findsNothing);
    },
  );
}
