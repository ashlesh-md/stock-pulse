import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/widgets/pending_badge.dart';

import '../../helpers/sp_app.dart';

void main() {
  testWidgets('shows Pending and speaks Order pending', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(spApp(PendingBadge(key: UniqueKey())));

    expect(find.text('Pending'), findsOneWidget);
    expect(find.bySemanticsLabel('Order pending'), findsOneWidget);
    semantics.dispose();
  });
}
