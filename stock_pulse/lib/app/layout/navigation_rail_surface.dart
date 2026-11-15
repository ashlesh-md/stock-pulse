import 'package:flutter/material.dart';

class NavigationRailSurface extends StatelessWidget {
  const NavigationRailSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      key: const ValueKey('navigation-rail-surface'),
      color:
          theme.navigationRailTheme.backgroundColor ??
          theme.colorScheme.surface,
      child: child,
    );
  }
}
