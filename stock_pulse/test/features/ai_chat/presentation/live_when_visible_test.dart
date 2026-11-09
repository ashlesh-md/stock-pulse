import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_view.dart';
import 'package:stock_pulse/features/market/application/live_quote_provider.dart';
import 'package:stock_pulse/features/market/di/market_data_providers.dart';
import 'package:stock_pulse/features/market/domain/quote.dart';

import '../../../helpers/fake_market_repository.dart';

void main() {
  testWidgets('quote feed follows 60 percent visibility and tab visibility', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var listens = 0;
    var cancels = 0;
    final now = DateTime.utc(2026, 11, 8, 12);
    final feed = StreamController<Quote>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    addTearDown(() async => feed.close());
    final container = ProviderContainer(
      overrides: [
        marketRepositoryProvider.overrideWithValue(FakeMarketRepository()),
        freshnessTickProvider.overrideWith((ref) => Stream.value(now)),
        liveQuoteProvider((id: 'TCS', throttleMs: 1000))
            .overrideWith((ref) => feed.stream),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(selectedTabProvider.notifier)
        .mirror(kTabs.indexOf(ScreenId.ai));
    final scroll = ScrollController();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: SingleChildScrollView(
                controller: scroll,
                child: Column(
                  children: [
                    AiCardView(
                      card: AiCard(
                        id: 'visible-quote',
                        type: 'quote',
                        title: 'TCS',
                        fallbackText: '',
                        body: {
                          'id': 'TCS',
                          'ltp': 3500,
                          // Keep the card taller than the viewport so the
                          // test exercises partial visibility thresholds.
                          'paragraphs': List<String>.filled(
                            12,
                            'Quote visibility controls the live market subscription.',
                          ),
                        },
                        asOf: now,
                      ),
                      onExplain: (_) {},
                    ),
                    const SizedBox(height: 1200),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(listens, 1);

    final cardHeight = tester.getSize(find.byType(AiCardView)).height;
    expect(cardHeight, greaterThan(600));
    expect(cardHeight, lessThan(1000));
    scroll.jumpTo(cardHeight * 0.4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(listens, 1, reason: '60% visible stays subscribed');

    scroll.jumpTo(cardHeight * 0.6);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(cancels, 0, reason: 'visibility changes are debounced');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(cancels, 1, reason: '40% visible releases the quote feed');

    scroll.jumpTo(cardHeight * 0.4);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(listens, 2);

    container
        .read(selectedTabProvider.notifier)
        .mirror(kTabs.indexOf(ScreenId.watchlist));
    await tester.pump();
    await tester.pump();
    expect(cancels, 2, reason: 'an inactive tab releases its live quote');
    expect(tester.takeException(), isNull);
    scroll.dispose();
  });
}
