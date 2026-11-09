import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

import '../app_harness.dart';

void main() {
  late AppHarness h;
  setUp(() => h = AppHarness());

  Future<void> pumpAt(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(h.app());
    await tester.pump();
  }

  double shortcutOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.byKey(const ValueKey('shortcut-visibility')),
      )
      .opacity;

  double quickTabOpacity(WidgetTester tester, int index) => tester
      .widget<AnimatedOpacity>(
        find.descendant(
          of: find.byKey(ValueKey('quick-tab-$index')),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('collapsed shortcut flows into circular tab buttons', (
    tester,
  ) async {
    await pumpAt(tester, 500);
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    final shortcut = find.byTooltip('Tabs');
    final before = tester.getCenter(shortcut);
    await tester.drag(shortcut, const Offset(-72, -60));
    await tester.pumpAndSettle();
    final after = tester.getCenter(shortcut);
    expect(after.dx, lessThan(before.dx - 40));
    expect(after.dy, lessThan(before.dy - 30));

    await tester.tap(find.byTooltip('Tabs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('Watchlist'), findsOneWidget);
    expect(find.byTooltip('Options'), findsOneWidget);
    expect(find.byTooltip('AI'), findsNothing);
    expect(find.byTooltip('Portfolio'), findsOneWidget);
    expect(find.byTooltip('More'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester
          .widget<IgnorePointer>(find.byKey(const ValueKey('quick-tab-0')))
          .ignoring,
      isTrue,
    );
    await tester.tap(find.byTooltip('Tabs'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byTooltip('Portfolio'));
    await tester.pumpAndSettle();
    expect(h.router(tester).state.uri.path, PortfolioRoute.path);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(shortcutOpacity(tester), 0);
  });

  testWidgets('the shortcut rests bottom-right and fans its tabs upward, '
      'apart and on screen', (tester) async {
    await pumpAt(tester, 500);
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    final shortcut = tester.getRect(find.byTooltip('Tabs'));
    expect(shortcut.left, greaterThanOrEqualTo(500 - 56 - SpSpace.s3));
    expect(shortcut.right, lessThanOrEqualTo(500 - SpSpace.s3));
    expect(shortcut.top, greaterThan(800 * 2 / 3));

    await tester.tap(find.byTooltip('Tabs'));
    await tester.pumpAndSettle();
    final buttons = [
      for (final label in ['Watchlist', 'Options', 'Portfolio', 'More'])
        tester.getRect(find.byTooltip(label)),
    ];
    for (final (i, a) in buttons.indexed) {
      expect(a.bottom, lessThanOrEqualTo(800));
      expect(a.center.dy, lessThanOrEqualTo(shortcut.bottom));
      for (final b in buttons.skip(i + 1)) {
        expect((a.center - b.center).distance, greaterThanOrEqualTo(48));
      }
    }
  });

  testWidgets('moved up to mid-screen, the shortcut fans its tabs in a '
      'half circle beside it', (tester) async {
    await pumpAt(tester, 500);
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    await tester.drag(find.byTooltip('Tabs'), const Offset(0, -320));
    await tester.pumpAndSettle();
    final anchor = tester.getCenter(find.byTooltip('Tabs'));

    await tester.tap(find.byTooltip('Tabs'));
    await tester.pumpAndSettle();
    final above = tester.getCenter(find.byTooltip('Watchlist'));
    final below = tester.getCenter(find.byTooltip('More'));
    expect(above.dy, lessThan(anchor.dy));
    expect(below.dy, greaterThan(anchor.dy));
    expect(above.dx, lessThan(anchor.dx));
  });

  testWidgets('radial tab buttons fan out and retract with motion', (
    tester,
  ) async {
    await pumpAt(tester, 500);
    await tester.tap(find.text('AI'));
    await tester.pumpAndSettle();
    expect(quickTabOpacity(tester, 0), 0);

    await tester.tap(find.byTooltip('Tabs'));
    await tester.pumpAndSettle();
    expect(quickTabOpacity(tester, 0), 1);
    final openingSlide = tester.widget<AnimatedSlide>(
      find.descendant(
        of: find.byKey(const ValueKey('quick-tab-0')),
        matching: find.byType(AnimatedSlide),
      ),
    );
    expect(openingSlide.offset, Offset.zero);
    expect(openingSlide.duration, greaterThan(Duration.zero));

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(quickTabOpacity(tester, 0), 0);
    final closingSlide = tester.widget<AnimatedSlide>(
      find.descendant(
        of: find.byKey(const ValueKey('quick-tab-0')),
        matching: find.byType(AnimatedSlide),
      ),
    );
    expect(closingSlide.offset, isNot(Offset.zero));
  });
}
