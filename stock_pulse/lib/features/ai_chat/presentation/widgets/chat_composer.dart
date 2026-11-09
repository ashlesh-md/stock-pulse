import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/features/ai_chat/domain/attachment_pick.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_attachment.dart';
import 'package:stock_pulse/features/ai_chat/domain/chat_limits.dart';
import 'package:stock_pulse/features/ai_chat/presentation/widgets/attachment_preview.dart';

/// Text field with attach, send and stop. The field stays editable while an
/// answer streams so the next question can be typed; only sending waits.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.busy,
    required this.onSend,
    required this.onStop,
    required this.onPickAttachment,
  });
  final bool busy;
  final void Function(String, List<ChatAttachment>) onSend;
  final VoidCallback onStop;
  final Future<AttachmentPick> Function() onPickAttachment;
  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _text = TextEditingController();
  final _attachments = <ChatAttachment>[];
  bool _picking = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final s = context.strings.chat;
    setState(() {
      _picking = true;
      _error = null;
    });
    final result = await widget.onPickAttachment();
    if (!mounted) return;
    setState(() {
      _picking = false;
      switch (result) {
        case AttachmentPicked(:final attachment):
          _attachments.add(attachment);
        case AttachmentCancelled():
          break;
        case AttachmentTooLarge():
          _error = s.attachmentLimit(
            ChatLimits.maxAttachmentBytes ~/ (1024 * 1024),
          );
        case AttachmentFailed():
          _error = s.attachmentError;
      }
    });
  }

  bool get _canSend {
    final text = _text.text.trim();
    return !widget.busy &&
        text.isNotEmpty &&
        text.length <= ChatLimits.maxQuestion;
  }

  void _send() {
    if (!_canSend) return;
    widget.onSend(_text.text.trim(), List.of(_attachments));
    _text.clear();
    setState(() {
      _attachments.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.chat;
    final sp = context.sp;
    final full = _attachments.length >= ChatLimits.maxAttachments;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: sp.surface0,
        border: Border(top: BorderSide(color: sp.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SpSpace.s3,
            SpSpace.s2,
            SpSpace.s3,
            SpSpace.s2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_attachments.isNotEmpty) ...[
                Wrap(
                  spacing: SpSpace.s2,
                  runSpacing: SpSpace.s2,
                  children: [
                    for (final attachment in _attachments)
                      AttachmentPreview(
                        attachment: attachment,
                        onRemove: () =>
                            setState(() => _attachments.remove(attachment)),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: SpSpace.s1),
                  child: Text(
                    s.attachmentNote,
                    style: context.spText.caption.copyWith(
                      color: sp.textTertiary,
                    ),
                  ),
                ),
              ],
              if (_error case final error?)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: SpSpace.s1),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: full
                        ? s.attachLimitReached(ChatLimits.maxAttachments)
                        : s.attach,
                    onPressed: _picking || full
                        ? null
                        : () => unawaited(_pick()),
                    icon: _picking
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.attach),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: ChatLimits.maxQuestion,
                      buildCounter: (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: s.hint,
                        isDense: true,
                        filled: true,
                        fillColor: sp.surface1,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: SpSpace.s4,
                          vertical: SpSpace.s3,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SpRadius.l + 8),
                          borderSide: BorderSide(color: sp.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SpRadius.l + 8),
                          borderSide: BorderSide(color: sp.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SpRadius.l + 8),
                          borderSide: BorderSide(color: sp.accent, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: SpSpace.s2),
                  IconButton.filled(
                    tooltip: widget.busy ? s.stop : s.send,
                    onPressed: widget.busy
                        ? widget.onStop
                        : _canSend
                        ? _send
                        : null,
                    icon: Icon(widget.busy ? AppIcons.stop : AppIcons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
