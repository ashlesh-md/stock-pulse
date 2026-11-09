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
  });

  final Widget title;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) => AppBar(
    centerTitle: false,
    title: DefaultTextStyle.merge(
      overflow: TextOverflow.ellipsis,
      child: title,
    ),
    actions: [...actions, const ConnectionBadge()],
    bottom: bottom,
  );
}
