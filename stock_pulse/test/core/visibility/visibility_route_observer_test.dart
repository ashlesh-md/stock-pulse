import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';
import 'package:stock_pulse/core/visibility/domain/covered_state.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';

import 'visibility_harness.dart';

void main() {
  late VisibilityHarness h;

  setUp(() => h = VisibilityHarness());
  tearDown(() => h.container.dispose());

  CoveredState covered() => h.container.read(coveredStateProvider);

  ModalBottomSheetRoute<void> sheet() => ModalBottomSheetRoute<void>(
    builder: (_) => const SizedBox(height: 200, child: Text('ticket')),
    isScrollControlled: false,
  );

  testWidgets('T13 FR-86: opaque stockDetail hides the watchlist; a sheet '
      'over it keeps stockDetail visible; pop restores the watchlist', (
    tester,
  ) async {
    await tester.pumpWidget(h.app());
    expect(h.visible(ScreenId.watchlist), isTrue);
    expect(h.visible(ScreenId.stockDetail), isFalse);

    unawaited(h.pushPage(ScreenId.stockDetail));
    await tester.pumpAndSettle();
    expect(h.visible(ScreenId.watchlist), isFalse);
    expect(h.visible(ScreenId.stockDetail), isTrue);
    expect(
      covered(),
      const CoveredState(topOpaque: ScreenId.stockDetail, opaqueDepth: 1),
    );

    unawaited(h.navigator.push(sheet()));
    await tester.pumpAndSettle();
    expect(h.visible(ScreenId.stockDetail), isTrue);

    h.navigator.pop();
    await tester.pumpAndSettle();
    expect(h.visible(ScreenId.stockDetail), isTrue);

    h.navigator.pop();
    await tester.pumpAndSettle();
    expect(h.visible(ScreenId.watchlist), isTrue);
    expect(h.visible(ScreenId.stockDetail), isFalse);
    expect(covered(), CoveredState.shell);
  });

  testWidgets('T14 ADR-0004: an opaque route with no ScreenId over Options '
      'hides it', (tester) async {
    await tester.pumpWidget(h.app());
    h.container.read(selectedTabProvider.notifier).mirror(1);
    await tester.pump();
    expect(h.visible(ScreenId.options), isTrue);

    unawaited(h.pushPage(null));
    await tester.pumpAndSettle();

    expect(h.visible(ScreenId.options), isFalse);
    expect(covered(), const CoveredState(topOpaque: null, opaqueDepth: 1));
  });

  testWidgets('the shell page never counts as a cover', (tester) async {
    await tester.pumpWidget(h.app());

    expect(covered(), CoveredState.shell);
    expect(h.visible(ScreenId.watchlist), isTrue);
  });

  testWidgets('a cold start on a linked page with no shell under it counts '
      'that page as the cover', (tester) async {
    await tester.pumpWidget(h.app(initialPages: [ScreenId.stockDetail.name]));

    expect(
      covered(),
      const CoveredState(topOpaque: ScreenId.stockDetail, opaqueDepth: 1),
    );
    expect(h.visible(ScreenId.watchlist), isFalse);
  });

  testWidgets('pages added during one build publish once, after the frame', (
    tester,
  ) async {
    var emits = 0;
    h.container.listen(coveredStateProvider, (_, _) => emits++);

    await tester.pumpWidget(
      h.app(
        initialPages: [
          kShellPageName,
          ScreenId.stockDetail.name,
          ScreenId.alerts.name,
        ],
      ),
    );

    expect(emits, 1);
    expect(
      covered(),
      const CoveredState(topOpaque: ScreenId.alerts, opaqueDepth: 2),
    );
  });

  testWidgets('pushReplacement of stockDetail keeps depth 1', (tester) async {
    await tester.pumpWidget(h.app());
    unawaited(h.pushPage(ScreenId.stockDetail));
    await tester.pumpAndSettle();

    unawaited(
      h.navigator.pushReplacement(
        VisibilityHarness.page(ScreenId.stockDetail.name),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      covered(),
      const CoveredState(topOpaque: ScreenId.stockDetail, opaqueDepth: 1),
    );

    h.navigator.pop();
    await tester.pumpAndSettle();
    expect(h.visible(ScreenId.watchlist), isTrue);
  });

  testWidgets('replacing a page with a sheet drops the cover', (tester) async {
    await tester.pumpWidget(h.app());
    unawaited(h.pushPage(ScreenId.alerts));
    await tester.pumpAndSettle();
    final top = ModalRoute.of(tester.element(find.text('alerts')))!;

    h.navigator.replace(oldRoute: top, newRoute: sheet());
    await tester.pumpAndSettle();

    expect(covered(), CoveredState.shell);
  });

  testWidgets('replacing a sheet with a page adds the page as a cover', (
    tester,
  ) async {
    await tester.pumpWidget(h.app());
    final bottom = sheet();
    unawaited(h.navigator.push(bottom));
    await tester.pumpAndSettle();
    expect(covered(), CoveredState.shell);

    h.navigator.replace(
      oldRoute: bottom,
      newRoute: VisibilityHarness.page(ScreenId.alerts.name),
    );
    await tester.pumpAndSettle();

    expect(
      covered(),
      const CoveredState(topOpaque: ScreenId.alerts, opaqueDepth: 1),
    );
  });

  testWidgets('removing a covered page below the top keeps the top', (
    tester,
  ) async {
    await tester.pumpWidget(h.app());
    unawaited(h.pushPage(ScreenId.alerts));
    await tester.pumpAndSettle();
    final alerts = ModalRoute.of(tester.element(find.text('alerts')))!;
    unawaited(h.pushPage(ScreenId.stockDetail));
    await tester.pumpAndSettle();

    h.navigator.removeRoute(alerts);
    await tester.pumpAndSettle();

    expect(
      covered(),
      const CoveredState(topOpaque: ScreenId.stockDetail, opaqueDepth: 1),
    );
  });

  testWidgets('removing a route it never tracked publishes nothing', (
    tester,
  ) async {
    await tester.pumpWidget(h.app());
    final bottom = sheet();
    unawaited(h.navigator.push(bottom));
    await tester.pumpAndSettle();
    var emits = 0;
    h.container.listen(coveredStateProvider, (_, _) => emits++);

    h.navigator.removeRoute(bottom);
    await tester.pumpAndSettle();

    expect(emits, 0);
  });
}
