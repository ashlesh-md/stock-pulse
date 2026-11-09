import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_rich_text.dart';

import '../../../helpers/sp_app.dart';

void main() {
  testWidgets('renders headings, emphasis, inline code, and list markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        const ChatRichText(
          text: '# Outlook\nA **strong** and *useful* `price` view.\n- First item\n2. Second item',
        ),
      ),
    );

    final blocks = tester.widgetList<SelectableText>(
      find.byType(SelectableText),
    );
    expect(blocks, hasLength(4));
    expect(blocks.first.textSpan!.toPlainText(), 'Outlook');
    expect(blocks.last.textSpan!.toPlainText(), '2.  Second item');

    final inline = blocks.elementAt(1).textSpan!;
    final styles = inline.children!.cast<TextSpan>();
    expect(
      styles.firstWhere((span) => span.text == 'strong').style?.fontWeight,
      FontWeight.w700,
    );
    expect(
      styles.firstWhere((span) => span.text == 'useful').style?.fontStyle,
      FontStyle.italic,
    );
    expect(
      styles.firstWhere((span) => span.text == 'price').style?.fontFamily,
      'monospace',
    );
  });

  testWidgets('keeps blank paragraphs and plain text intact', (tester) async {
    await tester.pumpWidget(
      spApp(const ChatRichText(text: 'First\n\nPlain _unfinished text')),
    );

    expect(find.byType(SizedBox), findsOneWidget);
    final blocks = tester.widgetList<SelectableText>(
      find.byType(SelectableText),
    );
    expect(blocks, hasLength(2));
    expect(blocks.first.textSpan!.toPlainText(), 'First');
    expect(blocks.last.textSpan!.toPlainText(), 'Plain _unfinished text');
  });
}
