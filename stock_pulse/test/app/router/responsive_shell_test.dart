import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/di/layout_providers.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/features/ai_chat/presentation/screens/ai_chat_screen.dart';
import 'package:stock_pulse/features/market/presentation/screens/stock_detail_screen.dart';
import 'package:stock_pulse/features/market/presentation/screens/watchlist_screen.dart';

import '../app_harness.dart';

void main() {
  late AppHarness h;
  setUp(() => h = AppHarness());

  Future<void> pumpAt(
    WidgetTester tester,
    double width, {
    double height = 800,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(h.app());
    await tester.pump();
  }

  NavigationRail rail(WidgetTester tester) =>
      tester.widget<NavigationRail>(find.byType(NavigationRail));

  double shortcutOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.byKey(const ValueKey('shortcut-visibility')),
      )
      .opacity;

  testWidgets('compact uses a bar and medium a rail, keeping the tab', (
    tester,
  ) async {
    await pumpAt(tester, 500);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1000, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(rail(tester).extended, isFalse);
    expect(rail(tester).labelType, NavigationRailLabelType.all);
    expect(rail(tester).selectedIndex, 4);
    expect(find.text('Add funds'), findsOneWidget);
  });

  testWidgets('expanded uses an extended rail', (tester) async {
    await pumpAt(tester, 1440);
    expect(rail(tester).extended, isTrue);
    expect(rail(tester).labelType, NavigationRailLabelType.none);
  });

  testWidgets('compact bottom bar animates away for the keyboard and returns', (
    tester,
  ) async {
    await pumpAt(tester, 500);
    final bar = find.byType(NavigationBar);
    expect(tester.getSize(bar).height, greaterThan(0));

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Tabs'), findsNothing);

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getSize(bar).height, greaterThan(0));
  });

  testWidgets('compact chat tab never shows the bottom navigation bar', (
    tester,
  ) async {
    await pumpAt(tester, 500);
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('Tabs'), findsOneWidget);
  });

  testWidgets(
    'compact bottom bar hides on downward scroll and returns upward',
    (tester) async {
      await pumpAt(tester, 500, height: 320);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      final list = find.byType(ListView).first;
      final bar = find.byType(NavigationBar);

      await tester.drag(list, const Offset(0, -160));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(NavigationBar), findsNothing);
      expect(shortcutOpacity(tester), 0);

      await tester.drag(list, const Offset(0, 80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getSize(bar).height, greaterThan(0));

      await tester.drag(list, const Offset(0, -80));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(shortcutOpacity(tester), 0);
      await tester.drag(list, const Offset(0, 600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.getSize(bar).height, greaterThan(0));
    },
  );

  testWidgets('with a rail the chat has no floating shortcut', (tester) async {
    await pumpAt(tester, 1000);
    h.router(tester).goTo(const AiChatRoute());
    await tester.pumpAndSettle();
    expect(find.byTooltip('Tabs'), findsNothing);
    expect(find.byTooltip('New chat'), findsOneWidget);
  });

  testWidgets('chat column is centred at the list width on wide windows', (
    tester,
  ) async {
    await pumpAt(tester, 1440);
    h.router(tester).goTo(const AiChatRoute());
    await tester.pumpAndSettle();
    final chat = tester.getRect(find.byType(AiChatScreen));
    final rail = tester.getRect(find.byType(NavigationRail)).right + 1;
    expect(chat.width, 840);
    expect(chat.center.dx, closeTo(rail + (1440 - rail) / 2, 1));
  });

  testWidgets('list screens are capped at the list width on wide windows', (
    tester,
  ) async {
    await pumpAt(tester, 1000);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppBar).last).width, 840);
  });

  testWidgets('expanded: a stock picked from the watchlist opens beside it, '
      'without a route', (tester) async {
    await pumpAt(tester, 1440);
    expect(find.text('Pick a stock to see its chart and depth.'), findsOne);

    tester
        .element(find.byType(WatchlistScreen))
        .pushTo<void>(const StockRoute('RELIANCE'))
        .ignore();
    await tester.pumpAndSettle();

    expect(find.byType(StockDetailScreen), findsOneWidget);
    expect(find.byType(WatchlistScreen), findsOneWidget);
    expect(h.router(tester).state.name, WatchlistRoute.name);
    expect(h.container(tester).read(stockPaneProvider), 'RELIANCE');
  });

  testWidgets('medium: a stock from the watchlist is pushed as a page', (
    tester,
  ) async {
    await pumpAt(tester, 1000);
    tester
        .element(find.byType(WatchlistScreen))
        .pushTo<void>(const StockRoute('TCS'))
        .ignore();
    await tester.pumpAndSettle();

    expect(h.router(tester).state.name, StockRoute.name);
    expect(h.container(tester).read(stockPaneProvider), isNull);
  });
}
