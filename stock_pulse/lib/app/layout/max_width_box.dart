import 'package:flutter/material.dart';

/// Centres [child] and caps its width at [maxWidth]; narrower windows get the
/// full width. The margins take the scaffold colour, so a capped page on its
/// own route never shows the window behind it.
class MaxWidthBox extends StatelessWidget {
  const MaxWidthBox({super.key, required this.maxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    ),
  );
}
