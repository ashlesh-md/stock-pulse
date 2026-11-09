import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:stock_pulse/app/di/layout_providers.dart';
import 'package:stock_pulse/app/layout/window_class.dart';
import 'package:stock_pulse/app/router/movable_tab_shortcut.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/visibility/di/visibility_providers.dart';

/// The tab bar around the shell's branches: a bottom bar on compact windows,
/// a rail on medium ones and an extended rail on expanded ones. The only writer of
/// `selectedTabProvider`, which mirrors [navigationShell]'s index.
class AppShellScaffold extends ConsumerStatefulWidget {
  const AppShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold> {
  bool _showBottomBar = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _mirrorAfterFrame();
  }

  @override
  void didUpdateWidget(AppShellScaffold old) {
    super.didUpdateWidget(old);
    if (old.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _lastScrollOffset = 0;
      _mirrorAfterFrame();
    }
  }

  void _mirrorAfterFrame() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    ref
        .read(selectedTabProvider.notifier)
        .mirror(widget.navigationShell.currentIndex);
  });

  void _select(int index) {
    _setBottomBar(true);
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final offset = notification.metrics.pixels;
    if (offset <= 0) {
      _setBottomBar(true);
    } else if (offset - _lastScrollOffset > 8) {
      _setBottomBar(false);
    } else if (_lastScrollOffset - offset > 8) {
      _setBottomBar(true);
    }
    _lastScrollOffset = offset;
    return false;
  }

  void _setBottomBar(bool visible) {
    if (_showBottomBar == visible) return;
    setState(() {
      _showBottomBar = visible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings.shell;
    final destinations = [
      (AppIcons.watchlist, s.watchlist),
      (AppIcons.options, s.options),
      (AppIcons.ai, s.ai),
      (AppIcons.portfolio, s.portfolio),
      (AppIcons.more, s.more),
    ];
    final window = context.windowClass;
    if (!window.usesRail) {
      final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
      final chatTab = widget.navigationShell.currentIndex == 2;
      final showShortcut = chatTab && !keyboardVisible;
      return Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: widget.navigationShell,
            ),
            if (!keyboardVisible)
              MovableTabShortcut(
                destinations: destinations,
                selectedIndex: widget.navigationShell.currentIndex,
                onSelect: _select,
                visible: showShortcut,
                dockHeight: ref.watch(chatDockHeightProvider),
              ),
          ],
        ),
        bottomNavigationBar: _animatedBottomBar(
          destinations,
          widget.navigationShell.currentIndex,
        ),
      );
    }
    final extended = window == WindowClass.expanded;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: _select,
              extended: extended,
              minExtendedWidth: 200,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final (icon, label) in destinations)
                  NavigationRailDestination(
                    icon: Icon(icon),
                    label: Text(label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
  }

  Widget _animatedBottomBar(
    List<(IconData, String)> destinations,
    int selectedIndex,
  ) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showBar = _showBottomBar && !keyboardVisible && selectedIndex != 2;
    return ClipRect(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        height: showBar ? 80 + bottomInset : 0,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .18),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: showBar
              ? NavigationBar(
                  key: const ValueKey('full-navigation'),
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) {
                    _setBottomBar(true);
                    _select(index);
                  },
                  destinations: [
                    for (final (icon, label) in destinations)
                      NavigationDestination(icon: Icon(icon), label: label),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('hidden-navigation')),
        ),
      ),
    );
  }
}
