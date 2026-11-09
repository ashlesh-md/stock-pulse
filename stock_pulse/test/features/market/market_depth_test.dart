import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';
import 'package:stock_pulse/features/market/presentation/widgets/market_depth.dart';

import '../../helpers/sp_app.dart';

void main() {
  testWidgets('empty depth reserves no space', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MarketDepth(bids: [], asks: []),
      ),
    );
    expect(find.byType(MarketDepth), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('depth title, prices, order counts and quantities align', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      spApp(
        const SizedBox(
          width: 700,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Market depth'),
                MarketDepth(
                  bids: [DepthLevel(price: 1472.25, quantity: 864, orders: 24)],
                  asks: [DepthLevel(price: 1472.35, quantity: 341, orders: 18)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.getRect(find.text('Market depth'));
    final bid = tester.getRect(find.text('Bid'));
    final bidPrice = tester.getRect(find.text('1,472.25'));
    final ask = tester.getRect(find.text('Ask'));
    final askPrice = tester.getRect(find.text('1,472.35'));
    expect(bid.left, title.left);
    expect(bidPrice.left, title.left);
    expect(ask.left, askPrice.left);

    final orderHeaders = find.text('Orders');
    final orderValues = [find.text('24').first, find.text('18').first];
    final quantityHeaders = find.text('Qty');
    final quantityValues = [find.text('864').first, find.text('341').first];
    for (var index = 0; index < 2; index++) {
      expect(
        tester.getRect(orderHeaders.at(index)).right,
        tester.getRect(orderValues[index]).right,
      );
      expect(
        tester.getRect(quantityHeaders.at(index)).right,
        tester.getRect(quantityValues[index]).right,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
