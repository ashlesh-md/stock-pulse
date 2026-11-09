import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_attachment.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/attachment_preview.dart';

import '../../../helpers/sp_app.dart';

void main() {
  testWidgets('file attachment shows its name, size and remove action', (
    tester,
  ) async {
    var removed = false;
    await tester.pumpWidget(
      spApp(
        AttachmentPreview(
          attachment: const ChatAttachment(name: 'report.pdf', size: 2048),
          onRemove: () => removed = true,
        ),
      ),
    );

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('2 KB'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove attachment'));
    expect(removed, isTrue);
  });

  testWidgets('image without preview bytes shows the image placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        const AttachmentPreview(
          attachment: ChatAttachment(name: 'chart.PNG', size: 512),
        ),
      ),
    );

    expect(find.byTooltip('Image'), findsNothing);
    expect(find.byType(Icon), findsOneWidget);
    expect(find.text('chart.PNG'), findsOneWidget);
  });

  testWidgets('invalid preview bytes fall back to the image icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        AttachmentPreview(
          attachment: ChatAttachment(
            name: 'broken.png',
            size: 3,
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Image preview unavailable'), findsOneWidget);
  });
}
