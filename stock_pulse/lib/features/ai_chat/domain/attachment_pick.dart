import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_attachment.dart';

/// A file the platform picker returned, before any limit is applied.
typedef PickedFile = ({String name, int size, Uint8List bytes});

/// Outcome of asking the user for an attachment.
sealed class AttachmentPick {
  const AttachmentPick();
}

final class AttachmentPicked extends AttachmentPick {
  const AttachmentPicked(this.attachment);
  final ChatAttachment attachment;
}

final class AttachmentCancelled extends AttachmentPick {
  const AttachmentCancelled();
}

/// Empty, or larger than the per-file limit.
final class AttachmentTooLarge extends AttachmentPick {
  const AttachmentTooLarge();
}

final class AttachmentFailed extends AttachmentPick {
  const AttachmentFailed();
}
