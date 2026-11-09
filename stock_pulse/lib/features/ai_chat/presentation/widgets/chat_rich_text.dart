import 'package:flutter/material.dart';
import 'package:stock_pulse/core/theme/sp_colors.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';

/// Selectable Markdown-like text for streamed AI cards.
class ChatRichText extends StatelessWidget {
  const ChatRichText({super.key, required this.text});
  final String text;

  static final _inline = RegExp(
    r'(\*\*.+?\*\*|__.+?__|`[^`]+`|\*[^*\n]+\*|_[^_\n]+_)',
  );
  static final _heading = RegExp(r'^(#{1,3})\s+(.+)$');
  static final _bullet = RegExp(r'^\s*[-*]\s+(.+)$');
  static final _number = RegExp(r'^\s*(\d+\.)\s+(.+)$');

  @override
  Widget build(BuildContext context) {
    final sp = context.sp;
    final base = Theme.of(context).textTheme.bodyMedium!
        .copyWith(color: sp.textSecondary);
    final lines = text.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          if (lines[i].trim().isEmpty)
            const SizedBox(height: 6)
          else
            _line(context, lines[i], base, sp),
      ],
    );
  }

  Widget _line(BuildContext context, String line, TextStyle base, SpColors sp) {
    final heading = _heading.firstMatch(line);
    final bullet = _bullet.firstMatch(line);
    final number = _number.firstMatch(line);
    final content =
        heading?.group(2) ?? bullet?.group(1) ?? number?.group(2) ?? line;
    final style = heading == null
        ? base
        : base.copyWith(
            fontSize: (base.fontSize ?? 14) + 2,
            fontWeight: FontWeight.w700,
            color: sp.textPrimary,
          );
    final prefix = bullet != null
        ? '•  '
        : number?.group(1) == null
        ? ''
        : '${number!.group(1)}  ';
    return Padding(
      padding: EdgeInsets.only(left: bullet != null || number != null ? 8 : 0),
      child: SelectableText.rich(
        TextSpan(
          style: style,
          children: [
            if (prefix.isNotEmpty) TextSpan(text: prefix),
            ..._spans(content, style, sp),
          ],
        ),
      ),
    );
  }

  List<InlineSpan> _spans(String text, TextStyle base, SpColors sp) {
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in _inline.allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      final value = match.group(0)!;
      final isCode = value.startsWith('`');
      final isBold = value.startsWith('**') || value.startsWith('__');
      final markerSize = isBold ? 2 : 1;
      final content = value.substring(markerSize, value.length - markerSize);
      spans.add(
        TextSpan(
          text: content,
          style: base.copyWith(
            fontWeight: isBold ? FontWeight.w700 : null,
            fontStyle: !isCode && !isBold ? FontStyle.italic : null,
            fontFamily: isCode ? 'monospace' : null,
            backgroundColor: isCode ? sp.surface2 : null,
          ),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return spans;
  }
}
