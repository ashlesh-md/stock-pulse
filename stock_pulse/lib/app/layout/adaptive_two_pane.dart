import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:stock_pulse/app/layout/fold_split.dart';
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
    this.globalOffset = Offset.zero,
  });

  final Widget primary;
  final Widget? secondary;
  final Widget placeholder;

  /// Width of [primary] beside the detail pane.
  final double primaryPaneWidth;

  /// Width cap of [primary] when it is shown alone.
  final double primaryMaxWidth;

  final Offset globalOffset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final feature = _splitFeature(context, constraints);
        final primaryContent = Center(
          child: SizedBox(
            width: math.min(primaryMaxWidth, constraints.maxWidth),
            child: primary,
          ),
        );
        if (feature != null) {
          return _foldSplit(
            axis: feature.axis,
            bounds: feature.bounds,
            primary: primaryContent,
            secondary: secondary ?? placeholder,
            constraints: constraints,
          );
        }
        final twoPanes = context.windowClass.showsTwoPanes;
        return Row(
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
        );
      },
    );
  }

  ({Axis axis, Rect bounds})? _splitFeature(
    BuildContext context,
    BoxConstraints constraints,
  ) => foldSplitOf(
    MediaQuery.displayFeaturesOf(context),
    constraints.biggest,
    offset: globalOffset,
  );

  Widget _foldSplit({
    required Axis axis,
    required Rect bounds,
    required Widget primary,
    required Widget secondary,
    required BoxConstraints constraints,
  }) {
    if (axis == Axis.vertical) {
      return Column(
        children: [
          SizedBox(height: bounds.top, child: primary),
          SizedBox(height: bounds.height),
          SizedBox(
            height: constraints.maxHeight - bounds.bottom,
            child: secondary,
          ),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: bounds.left, child: primary),
        SizedBox(width: bounds.width),
        SizedBox(width: constraints.maxWidth - bounds.right, child: secondary),
      ],
    );
  }
}
