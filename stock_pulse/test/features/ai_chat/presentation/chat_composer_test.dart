import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/ai_chat/domain/attachment_pick.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_attachment.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_limits.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/attachment_preview.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/chat_composer.dart';

import '../../../helpers/sp_app.dart';

void main() {
  testWidgets('picked attachments can be removed and sent with the question', (
    tester,
  ) async {
    String? sentText;
    List<ChatAttachment>? sentAttachments;
    var stops = 0;
    await tester.pumpWidget(
      spApp(
        ChatComposer(
          busy: false,
          onSend: (text, attachments) {
            sentText = text;
            sentAttachments = attachments;
          },
          onStop: () => stops++,
          onPickAttachment: () async => const AttachmentPicked(
            ChatAttachment(name: 'chart.png', size: 128),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Attach image or file'));
    await tester.pumpAndSettle();
    expect(find.byType(AttachmentPreview), findsOneWidget);
    await tester.tap(find.byTooltip('Remove attachment'));
    await tester.pump();
    expect(find.byType(AttachmentPreview), findsNothing);

    await tester.tap(find.byTooltip('Attach image or file'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Explain this chart  ');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(sentText, 'Explain this chart');
    expect(sentAttachments, [
      const ChatAttachment(name: 'chart.png', size: 128),
    ]);
    expect(find.text('chart.png'), findsNothing);
    expect(stops, 0);
  });

  testWidgets('cancelled and failed picks do not add an attachment', (
    tester,
  ) async {
    AttachmentPick result = const AttachmentCancelled();
    await tester.pumpWidget(
      spApp(
        ChatComposer(
          busy: false,
          onSend: (_, _) {},
          onStop: () {},
          onPickAttachment: () async => result,
        ),
      ),
    );
    await tester.tap(find.byTooltip('Attach image or file'));
    await tester.pumpAndSettle();
    expect(find.byType(AttachmentPreview), findsNothing);

    result = const AttachmentFailed();
    await tester.tap(find.byTooltip('Attach image or file'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not open the file picker. Try again.'),
      findsOneWidget,
    );
    expect(find.byType(AttachmentPreview), findsNothing);
  });

  testWidgets('oversized and empty picks show the attachment limit message', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        ChatComposer(
          busy: false,
          onSend: (_, _) {},
          onStop: () {},
          onPickAttachment: () async => const AttachmentTooLarge(),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Attach image or file'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a file between 1 byte and 5 MB.'), findsOneWidget);
  });

  testWidgets('busy state keeps the field editable and offers Stop', (
    tester,
  ) async {
    var stops = 0;
    await tester.pumpWidget(
      spApp(
        ChatComposer(
          busy: true,
          onSend: (_, _) {},
          onStop: () => stops++,
          onPickAttachment: () async => const AttachmentCancelled(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Next question');
    await tester.pump();
    expect(find.text('13/200'), findsNothing);
    await tester.tap(find.byTooltip('Stop answer'));
    expect(stops, 1);
    expect(
      tester.widget<TextField>(find.byType(TextField)).enabled,
      isNot(false),
    );
    expect(ChatLimits.maxQuestion, 200);
  });

  testWidgets('long question sends without showing a length counter', (
    tester,
  ) async {
    String? sent;
    await tester.pumpWidget(
      spApp(
        ChatComposer(
          busy: false,
          onSend: (text, _) => sent = text,
          onStop: () {},
          onPickAttachment: () async => const AttachmentCancelled(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'a' * 181);
    await tester.pump();
    expect(find.text('181/200'), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(sent, 'a' * 181);
    expect(find.text('181/200'), findsNothing);
  });

  testWidgets('attachment count disables picker at the configured maximum', (
    tester,
  ) async {
    var picks = 0;
    await tester.pumpWidget(
      spApp(
        ChatComposer(
          busy: false,
          onSend: (_, _) {},
          onStop: () {},
          onPickAttachment: () async {
            picks++;
            return const AttachmentPicked(
              ChatAttachment(name: 'chart.png', size: 10),
            );
          },
        ),
      ),
    );
    for (var i = 0; i < ChatLimits.maxAttachments; i++) {
      await tester.tap(find.byTooltip('Attach image or file'));
      await tester.pumpAndSettle();
    }

    final picker = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.attach_file),
    );
    expect(picker.onPressed, isNull);
    expect(picks, ChatLimits.maxAttachments);
    expect(find.byTooltip('Up to 3 attachments'), findsOneWidget);
  });
}
