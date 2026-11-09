import 'package:flutter/material.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// Follow-up prompts above the composer, one scrolling row.
class ChatFollowUps extends StatelessWidget {
  const ChatFollowUps({super.key, required this.prompts, required this.onTap});
  final List<String> prompts;
  final ValueChanged<String> onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: SpDensity.tap,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: SpSpace.gutter),
      itemCount: prompts.length,
      separatorBuilder: (_, _) => const SizedBox(width: SpSpace.s2),
      itemBuilder: (_, i) => Center(
        child: ActionChip(
          label: Text(prompts[i]),
          onPressed: () => onTap(prompts[i]),
        ),
      ),
    ),
  );
}
