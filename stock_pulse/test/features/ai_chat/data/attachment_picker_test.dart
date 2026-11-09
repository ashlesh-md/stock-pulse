import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/features/ai_chat/data/attachment_picker.dart';

void main() {
  test('a cancelled picker returns null', () async {
    expect(await pickChatFile(open: () async => null), isNull);
  });

  test('a picked file returns its name, size and bytes', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final file = await pickChatFile(
      open: () async =>
          XFile.fromData(bytes, name: 'chart.png', path: '/tmp/chart.png'),
    );
    expect(file?.name, 'chart.png');
    expect(file?.size, 3);
    expect(file?.bytes, bytes);
  });
}
