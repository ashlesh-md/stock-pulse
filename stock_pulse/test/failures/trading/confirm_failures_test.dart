import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/orders/application/order_draft.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/orders/presentation/widgets/order_confirm_bar.dart';

import '../../helpers/sp_app.dart';

void main() {
  const draft = OrderDraft(
    side: OrderSide.buy,
    type: OrderType.market,
    product: ProductType.cnc,
    count: 2,
    lotSize: 1,
    tickSize: .05,
    ltp: 100,
  );
  const reason = 'Prices are stale';

  testWidgets('F17 a disabled Confirm tapped five times in a second shows '
      'its reason and no snackbar', (tester) async {
    var confirms = 0;
    await tester.pumpWidget(
      spApp(
        Scaffold(
          body: OrderConfirmBar(
            symbol: 'TCS',
            draft: draft,
            blockReason: reason,
            onConfirm: () => confirms++,
          ),
        ),
      ),
    );

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(confirms, 0);
    expect(find.text(reason), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('F17 a send failure is shown once on the bar, not as a '
      'snackbar', (tester) async {
    await tester.pumpWidget(
      spApp(
        Scaffold(
          body: OrderConfirmBar(
            symbol: 'TCS',
            draft: draft.copyWith(error: () => 'Order rejected: price band'),
            onConfirm: () {},
          ),
        ),
      ),
    );

    expect(find.text('Order rejected: price band'), findsOneWidget);
    expect(find.text(reason), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });
}
