import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:stock_pulse/app/layout/window_class.dart';

/// A list pane beside a detail pane on expanded windows; [primary] alone,
/// centred and capped at [primaryMaxWidth], on compact and medium windows.
///
/// [secondary] is null until something is selected; [placeholder] fills the
/// detail pane until then. Each pane may be a full `Scaffold`. [primary]
/// keeps its element (and scroll position) when the window class changes.
class AdaptiveTwoPane extends StatelessWidget {
  const AdaptiveTwoPane({
    super.key,
    required this.primary,
    required this.placeholder,
    this.secondary,
    this.primaryPaneWidth = ContentWidth.listPane,
    this.primaryMaxWidth = ContentWidth.list,
  });

  final Widget primary;
  final Widget? secondary;
  final Widget placeholder;

  /// Width of [primary] beside the detail pane.
  final double primaryPaneWidth;

  /// Width cap of [primary] when it is shown alone.
  final double primaryMaxWidth;

  @override
  Widget build(BuildContext context) {
    final twoPanes = context.windowClass.showsTwoPanes;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: twoPanes
                ? primaryPaneWidth
                : math.min(primaryMaxWidth, constraints.maxWidth),
            child: primary,
          ),
          if (twoPanes) ...[
            const VerticalDivider(width: 1),
            Expanded(child: secondary ?? placeholder),
          ],
        ],
      ),
    );
  }
}
