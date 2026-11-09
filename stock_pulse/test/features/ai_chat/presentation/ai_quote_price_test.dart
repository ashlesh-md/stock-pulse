import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_view.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';

import '../../../helpers/fake_market_repository.dart';
import '../../../helpers/sp_app.dart';

void main() {
  Future<void> pumpQuoteCard(WidgetTester tester, Map<String, Object?> body) =>
      tester.pumpWidget(
        spApp(
          SingleChildScrollView(
            child: AiCardView(
              card: AiCard(
                id: 'q1',
                type: 'quote',
                title: 'RELIANCE',
                fallbackText: '',
                body: body,
                asOf: DateTime.utc(2026),
              ),
              onExplain: (_) {},
            ),
          ),
          overrides: [
            screenVisibleProvider(ScreenId.ai).overrideWithValue(false),
            marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
          ],
        ),
      );

  testWidgets('B24: the quote card price uses the shared price formatter', (
    tester,
  ) async {
    await pumpQuoteCard(tester, const {'id': 'RELIANCE', 'ltp': 1412.55});

    expect(find.text(Fmt.price(1412.55)), findsOneWidget);
    expect(find.text('1412.55'), findsNothing);
  });

  testWidgets('B24: a quote card without any price shows no empty price', (
    tester,
  ) async {
    await pumpQuoteCard(tester, const {'id': 'RELIANCE'});

    expect(find.textContaining('₹'), findsNothing);
  });
}
