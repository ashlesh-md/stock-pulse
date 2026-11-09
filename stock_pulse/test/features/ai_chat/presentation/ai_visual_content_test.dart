import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_visual_content.dart';
import 'package:stock_pulse/features/market/presentation/widgets/candle_chart.dart';
import 'package:stock_pulse/features/strategy/presentation/widgets/payoff_chart.dart';

import '../../../helpers/sp_app.dart';

AiCard _card(String type, Map<String, Object?> body) => AiCard(
  id: 'card',
  type: type,
  title: 'Visual',
  fallbackText: 'Summary',
  body: body,
);

void main() {
  testWidgets('renders chart points as a candle chart', (tester) async {
    await tester.pumpWidget(
      spApp(
        AiVisualContent(
          card: _card('chart', {
            'points': [
              [1794096000000, 100],
              [1794096300000, 102],
            ],
            'prevClose': 98,
          }),
        ),
      ),
    );

    expect(find.byType(CandleChart), findsOneWidget);
  });

  testWidgets('chain cells show prices and missing value dashes', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        AiVisualContent(
          card: _card('chain', {
            'rows': [
              {
                'ce': {'ltp': 12.5},
                'strike': 25000,
                'pe': null,
              },
            ],
          }),
        ),
      ),
    );

    expect(find.text('₹12.50'), findsOneWidget);
    expect(find.text('25000'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('empty chain has no rows and malformed cell shows a dash', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        AiVisualContent(
          card: _card('chain', {
            'rows': [
              {
                'ce': {'ltp': 'not-a-price'},
                'strike': 25000,
                'pe': {'ltp': 10},
              },
            ],
          }),
        ),
      ),
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text('₹10.00'), findsOneWidget);

    await tester.pumpWidget(spApp(AiVisualContent(card: _card('chain', {}))));
    expect(find.byType(Row), findsNothing);
  });

  testWidgets('payoff content handles an empty set and renders one leg', (
    tester,
  ) async {
    const expiry = 1796083200000;
    await tester.pumpWidget(
      spApp(
        AiVisualContent(
          card: _card('payoff', {
            'expiryAt': expiry,
            'legs': <Object?>[],
            'lotSize': 25,
            'spot': 25000,
          }),
        ),
      ),
    );
    expect(find.byType(PayoffChart), findsNothing);

    await tester.pumpWidget(
      spApp(
        AiVisualContent(
          card: _card('payoff', {
            'expiryAt': expiry,
            'legs': [
              {
                'right': 'CE',
                'strike': 25000,
                'side': 'sell',
                'lots': 1,
                'premium': 120,
                'iv': 0.2,
              },
            ],
            'lotSize': 25,
            'spot': 25000,
          }),
        ),
      ),
    );
    expect(find.byType(PayoffChart), findsOneWidget);
  });

  testWidgets('unsupported visual types render nothing', (tester) async {
    await tester.pumpWidget(spApp(AiVisualContent(card: _card('unknown', {}))));
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('payoff visual is hidden when more than four legs arrive', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        AiVisualContent(
          card: _card('payoff', {
            'expiryAt': 1796083200000,
            'lotSize': 25,
            'spot': 25000,
            'legs': [
              for (var i = 0; i < 5; i++)
                {
                  'right': 'CE',
                  'strike': 25000 + (i * 50),
                  'side': 'buy',
                  'lots': 1,
                  'premium': 120,
                  'iv': 0.2,
                },
            ],
          }),
        ),
      ),
    );
    expect(find.byType(PayoffChart), findsNothing);
  });
}
