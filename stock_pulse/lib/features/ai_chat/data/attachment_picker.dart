import 'package:file_selector/file_selector.dart';
import 'package:stock_pulse/features/ai_chat/domain/attachment_pick.dart';

/// Null when the user cancels the platform picker.
Future<PickedFile?> pickChatFile({
  Future<XFile?> Function() open = openFile,
}) async {
  final file = await open();
  if (file == null) return null;
  return (
    name: file.name,
    size: await file.length(),
    bytes: await file.readAsBytes(),
  );
}
