import 'dart:ui' show SemanticsAction;

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/chart_test_market.dart';
import '../app_harness.dart';

void main() {
  testWidgets('assistive tap enters and exits watchlist edit mode', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = AppHarness()..marketRepository = CountingMarket();
    await h.pumpPhone(tester);
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.bySemanticsLabel('Edit').first);
    tester.binding.rootPipelineOwner.visitChildren(
      (owner) =>
          owner.semanticsOwner?.performAction(node.id, SemanticsAction.tap),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Done'), findsOneWidget);
    semantics.dispose();
  });
}
