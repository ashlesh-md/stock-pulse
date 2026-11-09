import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/error/app_error.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/more/di/more_data_providers.dart';
import 'package:stock_pulse/features/more/domain/payment_method.dart';
import 'package:stock_pulse/features/more/presentation/screens/add_funds_screen.dart';
import 'package:stock_pulse/features/portfolio/domain/funds.dart';

import '../../helpers/fake_funds_transfer.dart';

void main() {
  late FakeFundsTransfer transfer;

  setUp(() => transfer = FakeFundsTransfer());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [fundsTransferProvider.overrideWithValue(transfer)],
      child: MaterialApp(theme: AppTheme.light(), home: const AddFundsScreen()),
    ),
  );

  testWidgets('a quick amount and net banking are sent on confirm, and the '
      'new balance is announced', (tester) async {
    transfer.result = const Success(Funds(available: 15000));
    await pump(tester);
    await tester.tap(find.text('₹5,000.00'));
    await tester.tap(find.text('Net banking'));
    await tester.pump();
    await tester.tap(find.text('Confirm demo payment'));
    await tester.pump();
    expect(transfer.calls.single.$1, 5000);
    expect(transfer.calls.single.$2, PaymentMethod.netBanking);
    expect(
      find.text('Funds added. Available balance ₹15,000.00'),
      findsOneWidget,
    );
  });

  testWidgets('an invalid amount shows the field error and sends nothing', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.textContaining('up to ₹1,00,00,000.00'), findsOneWidget);
    expect(transfer.calls, isEmpty);
  });

  testWidgets('while sending, inputs are disabled; a failure says a retry '
      'is safe', (tester) async {
    transfer
      ..gate = Completer<void>()
      ..result = const Failure(NetworkError());
    await pump(tester);
    await tester.tap(find.text('Confirm demo payment'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
    final chip = tester.widget<ActionChip>(find.byType(ActionChip).first);
    expect(chip.onPressed, isNull);

    transfer.gate!.complete();
    await tester.pump();
    expect(find.textContaining('Retry the same amount'), findsOneWidget);
    expect(transfer.calls.single.$1, 1000);
  });
}
