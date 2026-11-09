import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/theme/app_theme.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/appear_in.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_follow_ups.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/typing_indicator.dart';

void main() {
  testWidgets('follow-up chips send the selected suggestion', (tester) async {
    String? asked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: ChatFollowUps(
            prompts: const ['Compare peers', 'Explain volume'],
            onTap: (prompt) => asked = prompt,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Explain volume'));
    expect(asked, 'Explain volume');
  });

  testWidgets('reduced motion immediately settles entrance and typing dots', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Column(
              children: [
                AppearIn(animate: true, child: Text('Answer')),
                TypingIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Answer'), findsOneWidget);
    expect(tester.getSize(find.text('Answer')).height, greaterThan(0));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
