import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/orders/application/order_draft.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/presentation/widgets/order_confirm_bar.dart';

import '../../../helpers/sp_app.dart';

void main() {
  const draft = OrderDraft(
    side: OrderSide.buy,
    type: OrderType.market,
    product: ProductType.cnc,
    count: 2,
    lotSize: 1,
    tickSize: .05,
    ltp: 100,
    submitting: true,
  );

  Widget bar({bool checkingStatus = false}) => spApp(
    Scaffold(
      body: OrderConfirmBar(
        symbol: 'TCS',
        draft: draft,
        checkingStatus: checkingStatus,
        onConfirm: () => fail('Confirm must be disabled while sending'),
      ),
    ),
  );

  testWidgets('sending shows a disabled spinner with Placing', (tester) async {
    await tester.pumpWidget(bar());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Placing…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('a slow send says it is checking status', (tester) async {
    await tester.pumpWidget(bar(checkingStatus: true));

    expect(find.text('Checking status…'), findsOneWidget);
    expect(find.text('Placing…'), findsNothing);
  });
}
