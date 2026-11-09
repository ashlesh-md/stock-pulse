import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// Non-blocking order warnings. Dismissing a warning never changes eligibility.
class OrderNudgeStrip extends StatefulWidget {
  const OrderNudgeStrip({super.key, required this.messages});

  final List<String> messages;

  @override
  State<OrderNudgeStrip> createState() => _OrderNudgeStripState();
}

class _OrderNudgeStripState extends State<OrderNudgeStrip> {
  final Set<String> _dismissed = {};

  @override
  void didUpdateWidget(covariant OrderNudgeStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _dismissed.removeWhere((message) => !widget.messages.contains(message));
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.messages
        .where((message) => !_dismissed.contains(message))
        .toList();
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: visible.isEmpty
          ? const SizedBox.shrink()
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final message in visible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SpSpace.s1),
                    child: Material(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(
                          start: SpSpace.s3,
                          top: SpSpace.s2,
                          bottom: SpSpace.s2,
                          end: SpSpace.s1,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              AppIcons.info,
                              size: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onTertiaryContainer,
                            ),
                            const SizedBox(width: SpSpace.s2),
                            Expanded(
                              child: Text(
                                message,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            IconButton(
                              tooltip: MaterialLocalizations.of(context)
                                  .closeButtonTooltip,
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  setState(() => _dismissed.add(message)),
                              icon: const Icon(AppIcons.close, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
