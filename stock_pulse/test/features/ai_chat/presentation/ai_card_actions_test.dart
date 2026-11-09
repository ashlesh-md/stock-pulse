import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/core/analytics/application/analytics_service.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/ai_chat/domain/ai_card.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/ai_card_view.dart';
import 'package:stock_pulse/features/orders/domain/order.dart' show OrderSide;
import 'package:stock_pulse/features/strategy/di/strategy_providers.dart';

import '../../../helpers/fake_crash_reporter.dart';

void main() {
  late GoRouter router;

  setUp(() {
    _CardHost.card.value = null;
    _CardHost.onExplain = (_) {};
    router = GoRouter(
      initialLocation: '/ai',
      routes: [
        GoRoute(
          path: '/ai',
          builder: (_, _) => const Scaffold(body: _CardHost()),
        ),
        GoRoute(
          path: '/stock/:id',
          builder: (_, state) => Text('Stock ${state.pathParameters['id']}'),
        ),
        GoRoute(path: '/options', builder: (_, _) => const Text('Options')),
        GoRoute(
          path: '/order/:id',
          builder: (_, state) => Text('Order ${state.pathParameters['id']}'),
        ),
        GoRoute(path: '/strategy', builder: (_, _) => const Text('Strategy')),
      ],
    );
  });

  tearDown(() => router.dispose());

  Future<void> pumpCard(
    WidgetTester tester,
    AiCard card, {
    ValueChanged<String>? onExplain,
  }) async {
    _CardHost.card.value = card;
    _CardHost.onExplain = onExplain ?? (_) {};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsProvider.overrideWithValue(
            AnalyticsService(
              const [],
              FakeCrashReporter(),
              consent: () => true,
            ),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pump();
  }

  testWidgets('explain uses the term and renders soft rich text', (
    tester,
  ) async {
    String? prompt;
    await pumpCard(
      tester,
      AiCard(
        id: 'text-1',
        type: 'text',
        title: '',
        fallbackText: 'A **useful** explanation',
        actions: [
          AiAction('explain', 'Explain', {'term': 'VWAP'}),
        ],
      ),
      onExplain: (value) => prompt = value,
    );

    expect(find.text('A useful explanation'), findsOneWidget);
    await tester.tap(find.text('Explain'));
    expect(prompt, 'Explain VWAP');
  });

  testWidgets('unknown card retains readable text and the common disclaimer', (
    tester,
  ) async {
    await pumpCard(
      tester,
      AiCard(
        id: 'unknown-1',
        type: 'unknown',
        title: '',
        fallbackText: 'This card is still readable.',
      ),
    );

    expect(find.text('Explanation'), findsOneWidget);
    expect(find.text('This card is still readable.'), findsOneWidget);
    expect(find.text('Simulated. Not advice.'), findsOneWidget);
  });

  testWidgets('table rows with an id open their instrument', (tester) async {
    await pumpCard(
      tester,
      AiCard(
        id: 'table-1',
        type: 'table',
        title: 'Signals',
        fallbackText: '',
        body: const {
          'columns': [
            {'key': 'symbol', 'label': 'Symbol'},
            {'key': 'price', 'label': 'Price'},
          ],
          'rows': [
            {
              'id': 'RELIANCE',
              'cells': {'symbol': 'RELIANCE', 'price': 1250},
            },
          ],
        },
      ),
    );

    await tester.tap(find.text('RELIANCE'));
    await tester.pumpAndSettle();
    expect(find.text('Stock RELIANCE'), findsOneWidget);
  });

  testWidgets('stock, chain and order actions navigate with arguments', (
    tester,
  ) async {
    await pumpCard(
      tester,
      AiCard(
        id: 'quote-1',
        type: 'quote',
        title: 'TCS',
        fallbackText: '',
        body: const {'ltp': 3500, 'changePct': -0.5},
        actions: [
          AiAction('open_stock', 'Open', {'instrumentId': 'TCS'}),
        ],
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Stock TCS'), findsOneWidget);

    router.go('/ai');
    await tester.pumpAndSettle();
    _CardHost.card.value = AiCard(
      id: 'chain-1',
      type: 'chain',
      title: 'Options',
      fallbackText: '',
      actions: [
        AiAction('open_chain', 'Open chain', {
          'underlying': 'NIFTY',
          'expiry': '2026-11-26',
        }),
      ],
    );
    await tester.pump();
    await tester.tap(find.text('Open chain'));
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters, {'u': 'NIFTY', 'e': '2026-11-26'});

    router.go('/ai');
    await tester.pumpAndSettle();
    _CardHost.card.value = AiCard(
      id: 'trade-1',
      type: 'quote',
      title: 'TCS',
      fallbackText: '',
      actions: [
        AiAction('trade', 'Buy', {'id': 'TCS', 'side': 'sell', 'lots': 3}),
      ],
    );
    await tester.pump();
    await tester.tap(find.text('Buy'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/order/TCS');
    expect(router.state.uri.queryParameters['side'], 'sell');
    expect(router.state.uri.queryParameters['lots'], '3');

    for (final (kind, label) in [
      ('open_chart', 'Open chart'),
      ('set_alert', 'Set alert'),
    ]) {
      router.go('/ai');
      await tester.pumpAndSettle();
      _CardHost.card.value = AiCard(
        id: '$kind-1',
        type: 'text',
        title: 'Action',
        fallbackText: '',
        actions: [
          AiAction(kind, label, {'id': 'INFY'}),
        ],
      );
      await tester.pump();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('Stock INFY'), findsOneWidget);
    }
  });

  testWidgets('payoff action loads its draft before navigating', (
    tester,
  ) async {
    await pumpCard(
      tester,
      AiCard(
        id: 'payoff-1',
        type: 'payoff',
        title: 'Payoff',
        fallbackText: '',
        body: const {
          'expiryAt': 1796083200000,
          'lotSize': 25,
          'spot': 25000,
          'legs': [
            {
              'id': 'NIFTY-261126-25000-CE',
              'side': 'sell',
              'lots': 2,
              'premium': 120,
              'right': 'CE',
              'strike': 25000,
              'iv': 0.2,
            },
          ],
        },
        actions: [AiAction('view_payoff', 'View payoff', {})],
      ),
    );

    await tester.ensureVisible(find.text('View payoff'));
    await tester.tap(find.text('View payoff'));
    await tester.pumpAndSettle();
    expect(find.text('Strategy'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.text('Strategy')),
    );
    final draft = container.read(strategyDraftControllerProvider);
    expect(draft.shownLegs, hasLength(1));
    expect(draft.shownLegs.single.side, OrderSide.sell);
    expect(draft.shownLegs.single.lots, 2);
  });
}

class _CardHost extends StatefulWidget {
  const _CardHost();

  static final ValueNotifier<AiCard?> card = ValueNotifier(null);
  static ValueChanged<String>? onExplain;

  @override
  State<_CardHost> createState() => _CardHostState();
}

class _CardHostState extends State<_CardHost> {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _CardHost.card,
    builder: (context, card, _) => card == null
        ? const SizedBox.shrink()
        : SingleChildScrollView(
            child: AiCardView(
              card: card,
              onExplain: _CardHost.onExplain ?? (_) {},
            ),
          ),
  );
}
