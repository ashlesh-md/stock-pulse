import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_attachment.dart';

/// Chip for one attachment: thumbnail or file icon, name and size, and a
/// remove button when [onRemove] is set.
class AttachmentPreview extends StatelessWidget {
  const AttachmentPreview({super.key, required this.attachment, this.onRemove});
  final ChatAttachment attachment;
  final VoidCallback? onRemove;
  @override
  Widget build(BuildContext context) {
    final s = context.strings.chat;
    final sp = context.sp;
    final bytes = attachment.bytes;
    return Semantics(
      label: s.attachmentLabel(attachment.name, attachment.size),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: EdgeInsets.fromLTRB(
          SpSpace.s1,
          SpSpace.s1,
          onRemove == null ? SpSpace.s3 : 0,
          SpSpace.s1,
        ),
        decoration: BoxDecoration(
          color: sp.surface2,
          borderRadius: BorderRadius.circular(SpRadius.m),
          border: Border.all(color: sp.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(SpRadius.s),
              child: SizedBox.square(
                dimension: 40,
                child: attachment.isImage && bytes != null
                    ? Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Tooltip(
                          message: s.previewUnavailable,
                          child: const Icon(AppIcons.image),
                        ),
                      )
                    : ColoredBox(
                        color: sp.surface1,
                        child: Icon(
                          attachment.isImage ? AppIcons.image : AppIcons.file,
                          size: 20,
                          color: sp.textSecondary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: SpSpace.s2),
            Flexible(
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      s.size(attachment.size),
                      style: context.spText.caption.copyWith(
                        color: sp.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onRemove != null)
              IconButton(
                tooltip: s.removeAttachment,
                onPressed: onRemove,
                icon: const Icon(AppIcons.close, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
