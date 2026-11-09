import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/orders/domain/order.dart';
import 'package:stock_pulse/features/portfolio/presentation/widgets/order_tile.dart';

import '../../helpers/sp_app.dart';

void main() {
  testWidgets('a stop-loss order names its type', (tester) async {
    await tester.pumpWidget(
      spApp(
        Material(
          child: OrderTile(
            order: Order(
              id: 'o9',
              version: 1,
              symbol: 'TCS',
              side: OrderSide.sell,
              type: OrderType.sl,
              quantity: 3,
              status: OrderStatus.triggerPending,
              createdAt: DateTime.utc(2026, 11, 8, 4),
              updatedAt: DateTime.utc(2026, 11, 8, 4),
              limitPrice: 2990,
              triggerPrice: 2995,
            ),
            onCancel: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Stop loss'), findsOneWidget);
  });

  testWidgets('pending order offers refresh status instead of retry', (
    tester,
  ) async {
    var refreshes = 0;
    await tester.pumpWidget(
      spApp(
        Material(
          child: OrderTile(
            order: Order(
              id: 'pending:k1',
              clientKey: 'k1',
              symbol: 'TCS',
              side: OrderSide.buy,
              type: OrderType.market,
              quantity: 2,
              status: OrderStatus.pending,
              createdAt: DateTime.utc(2026, 11, 8, 4),
              updatedAt: DateTime.utc(2026, 11, 8, 4),
            ),
            onCancel: () {},
            onRefreshStatus: () => refreshes++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Refresh status'));
    expect(refreshes, 1);

    await tester.pumpWidget(
      spApp(
        Material(
          child: OrderTile(
            order: Order(
              id: 'pending:k1',
              clientKey: 'k1',
              symbol: 'TCS',
              side: OrderSide.buy,
              type: OrderType.market,
              quantity: 2,
              status: OrderStatus.pending,
              createdAt: DateTime.utc(2026, 11, 8, 4),
              updatedAt: DateTime.utc(2026, 11, 8, 4),
            ),
            onCancel: () {},
            onRefreshStatus: () => refreshes++,
            waitingForConnection: true,
          ),
        ),
      ),
    );
    expect(find.text('Waiting for connection'), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
  });
}
