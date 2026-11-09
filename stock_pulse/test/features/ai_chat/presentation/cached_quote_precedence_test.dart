import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_view.dart';
import 'package:stock_pulse/features/market/application/live_quote_provider.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

import '../../../helpers/fake_market_repository.dart';
import '../../../helpers/sp_app.dart';

void main() {
  testWidgets('newer repository quote wins over an older live replay', (
    tester,
  ) async {
    const id = 'TCS';
    final now = DateTime.utc(2026, 1, 2, 12);
    final older = Quote(
      symbol: id,
      ltp: 3490,
      change: 0,
      changePercent: 0,
      lastTradeTime: now.subtract(const Duration(minutes: 1)),
      asOf: now.subtract(const Duration(seconds: 10)),
    );
    final cached = Quote(
      symbol: id,
      ltp: 3501,
      change: 0,
      changePercent: 0,
      lastTradeTime: older.lastTradeTime,
      asOf: now,
    );
    await tester.pumpWidget(
      spApp(
        SingleChildScrollView(
          child: AiCardView(
            card: AiCard(
              id: 'q7',
              type: 'quote',
              title: 'TCS',
              fallbackText: '',
              body: const {'id': id, 'ltp': 3400},
              asOf: older.asOf,
            ),
            onExplain: (_) {},
          ),
        ),
        overrides: [
          marketRepositoryProvider.overrideWithValue(
            FakeMarketRepository(quotes: [cached]),
          ),
          screenVisibleProvider(ScreenId.ai).overrideWithValue(true),
          liveQuoteProvider((id: id, throttleMs: 1000))
              .overrideWith((ref) => Stream.value(older)),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(Fmt.price(3501)), findsOneWidget);
    expect(find.text(Fmt.price(3490)), findsNothing);
  });
}
