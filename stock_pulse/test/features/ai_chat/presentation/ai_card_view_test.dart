import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/core/widgets/stale_badge.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_view.dart';
import 'package:stock_pulse/features/market/application/live_quote_provider.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

import '../../../helpers/fake_market_repository.dart';
import '../../../helpers/sp_app.dart';

void main() {
  testWidgets(
    'a failed live quote keeps stale status alongside the refresh error',
    (tester) async {
      const id = 'TCS';
      await tester.pumpWidget(
        spApp(
          SingleChildScrollView(
            child: AiCardView(
              card: AiCard(
                id: 'q1',
                type: 'quote',
                title: 'TCS',
                fallbackText: '',
                body: const {'id': id, 'ltp': 3500, 'changePct': 0.5},
                asOf: DateTime.utc(2026),
              ),
              onExplain: (_) {},
            ),
          ),
          overrides: [
            screenVisibleProvider(ScreenId.ai).overrideWithValue(true),
            marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
            freshnessTickProvider.overrideWith(
              (ref) => Stream.value(DateTime.utc(2026, 1, 2)),
            ),
            liveQuoteProvider((id: id, throttleMs: 1000))
                .overrideWith((ref) => Stream.error(StateError('offline'))),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Could not refresh the live price.'), findsOneWidget);
      expect(find.byType(StaleBadge), findsOneWidget);
    },
  );

  testWidgets('stale quote status stays stable while its card scrolls away', (
    tester,
  ) async {
    const id = 'TCS';
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      spApp(
        SingleChildScrollView(
          child: Column(
            children: [
              AiCardView(
                card: AiCard(
                  id: 'q2',
                  type: 'quote',
                  title: 'TCS',
                  fallbackText: '',
                  body: const {'id': id, 'ltp': 3500, 'changePct': 0.5},
                  asOf: DateTime.utc(2026),
                ),
                onExplain: (_) {},
              ),
              const SizedBox(height: 600),
            ],
          ),
        ),
        overrides: [
          screenVisibleProvider(ScreenId.ai).overrideWithValue(true),
          marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
          freshnessTickProvider.overrideWith(
            (ref) => Stream.value(DateTime.utc(2026, 1, 2)),
          ),
          liveQuoteProvider((id: id, throttleMs: 1000))
              .overrideWith((ref) => const Stream.empty()),
        ],
      ),
    );
    await tester.pump();
    expect(find.byType(StaleBadge), findsOneWidget);

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byType(StaleBadge), findsOneWidget);
  });

  Widget host(AiCard card, {DateTime? now}) => spApp(
    SingleChildScrollView(
      child: AiCardView(card: card, onExplain: (_) {}),
    ),
    overrides: [
      screenVisibleProvider(ScreenId.ai).overrideWithValue(true),
      marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
      freshnessTickProvider.overrideWith(
        (ref) => Stream.value(now ?? DateTime.utc(2026, 1, 2)),
      ),
      liveQuoteProvider((id: 'TCS', throttleMs: 1000))
          .overrideWith((ref) => const Stream.empty()),
    ],
  );

  testWidgets('B12 an explanation card never shows freshness', (tester) async {
    await tester.pumpWidget(
      host(
        AiCard(
          id: 't1',
          type: 'text',
          title: 'Theta',
          fallbackText: 'Time decay.',
          asOf: DateTime.utc(2026),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StaleBadge), findsNothing);
    expect(find.textContaining('as of'), findsNothing);
  });

  testWidgets('B12 a quote confirmed now is not stale', (tester) async {
    await tester.pumpWidget(
      host(
        AiCard(
          id: 'q3',
          type: 'quote',
          title: 'TCS',
          fallbackText: '',
          body: const {'id': 'TCS', 'ltp': 3500},
          asOf: DateTime.utc(2026, 1, 2),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StaleBadge), findsNothing);
    expect(find.textContaining('as of'), findsOneWidget);
  });

  testWidgets('B12 a quote goes stale 5 s after it arrived without a frame', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 1, 2);
    await tester.pumpWidget(
      host(
        AiCard(
          id: 'q4',
          type: 'quote',
          title: 'TCS',
          fallbackText: '',
          body: const {'id': 'TCS', 'ltp': 3500},
          asOf: now.subtract(const Duration(milliseconds: 5100)),
        ),
        now: now,
      ),
    );
    await tester.pump();

    expect(find.byType(StaleBadge), findsOneWidget);
  });

  testWidgets('a quote is still fresh at exactly five seconds', (tester) async {
    final now = DateTime.utc(2026, 1, 2);
    await tester.pumpWidget(
      host(
        AiCard(
          id: 'q-exact-five',
          type: 'quote',
          title: 'TCS',
          fallbackText: '',
          body: const {'id': 'TCS', 'ltp': 3500},
          asOf: now.subtract(const Duration(seconds: 5)),
        ),
        now: now,
      ),
    );
    await tester.pump();

    expect(find.byType(StaleBadge), findsNothing);
  });

  testWidgets('a cached live quote prevents the snapshot flash on tab return', (
    tester,
  ) async {
    const id = 'TCS';
    final repository = FakeMarketRepository(
      quotes: [
        Quote.fromJson({
          's': id,
          'ltp': 3499.25,
          'ch': -0.75,
          'chp': -0.02,
          't': DateTime.utc(2026, 1, 2).millisecondsSinceEpoch,
        }),
      ],
    );
    await tester.pumpWidget(
      spApp(
        SingleChildScrollView(
          child: AiCardView(
            card: AiCard(
              id: 'q5',
              type: 'quote',
              title: 'TCS',
              fallbackText: '',
              body: const {'id': id, 'ltp': 3500},
              asOf: DateTime.utc(2026),
            ),
            onExplain: (_) {},
          ),
        ),
        overrides: [
          marketRepositoryProvider.overrideWithValue(repository),
          screenVisibleProvider(ScreenId.ai).overrideWithValue(true),
          liveQuoteProvider((id: id, throttleMs: 1000))
              .overrideWith((ref) => const Stream.empty()),
        ],
      ),
    );
    await tester.pump();

    expect(find.text(Fmt.price(3499.25)), findsOneWidget);
    expect(find.text(Fmt.price(3500)), findsNothing);
  });

  testWidgets(
    'keep-alive confirms freshness without advancing last trade time',
    (tester) async {
      const id = 'TCS';
      final now = DateTime.utc(2026, 1, 2, 12);
      final previousConfirmation = now.subtract(const Duration(seconds: 10));
      final lastTrade = now.subtract(const Duration(minutes: 2));
      final oldQuote = Quote(
        symbol: id,
        ltp: 3500,
        change: 0,
        changePercent: 0,
        lastTradeTime: lastTrade,
        asOf: previousConfirmation,
      );
      final confirmed = oldQuote.copyWith(asOf: now);
      final repository = FakeMarketRepository(quotes: [confirmed]);

      await tester.pumpWidget(
        spApp(
          SingleChildScrollView(
            child: AiCardView(
              card: AiCard(
                id: 'q6',
                type: 'quote',
                title: 'TCS',
                fallbackText: '',
                body: const {'id': id, 'ltp': 3400},
                asOf: previousConfirmation,
              ),
              onExplain: (_) {},
            ),
          ),
          overrides: [
            marketRepositoryProvider.overrideWithValue(repository),
            screenVisibleProvider(ScreenId.ai).overrideWithValue(true),
            freshnessTickProvider.overrideWith((ref) => Stream.value(now)),
            liveQuoteProvider((id: id, throttleMs: 1000))
                .overrideWith((ref) => Stream.value(oldQuote)),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(StaleBadge), findsNothing);
    },
  );
}
