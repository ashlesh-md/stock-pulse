import 'package:flutter/material.dart';
import 'package:stock_pulse/core/widgets/connection_badge.dart';

/// App bar for every tab root: title on the left on every platform, then
/// [actions], then the connection status at the right edge.
class SpTabAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SpTabAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.bottom,
    this.spacious = false,
  });

  final Widget title;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final bool spacious;

  static bool forLargeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) > 1.3;

  double get _toolbarHeight => kToolbarHeight + (spacious ? 16 : 0);

  @override
  Size get preferredSize =>
      Size.fromHeight(_toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: _toolbarHeight,
    centerTitle: false,
    title: DefaultTextStyle.merge(
      // Long translations would wrap and push the toolbar past its height.
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: title,
    ),
    actions: [...actions, const ConnectionBadge()],
    bottom: bottom,
  );
}
