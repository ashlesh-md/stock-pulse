import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

class MovableTabShortcut extends StatefulWidget {
  const MovableTabShortcut({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.visible,
    required this.dockHeight,
  });

  static const anchorSize = 56.0;

  /// Space a list above the dock keeps free at its end, so its last item can
  /// scroll clear of the docked button.
  static const dockClearance = anchorSize + SpSpace.s3;

  final List<(IconData, String)> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final bool visible;

  /// Height of the screen's bottom dock; until moved, the button rests at the
  /// right edge just above it.
  final double dockHeight;

  @override
  State<MovableTabShortcut> createState() => _MovableTabShortcutState();
}

class _MovableTabShortcutState extends State<MovableTabShortcut> {
  bool _showQuickTabs = false;
  double? _left;
  double? _top;

  void _closeQuickTabs() {
    if (!_showQuickTabs) return;
    setState(() => _showQuickTabs = false);
  }

  void _toggleQuickTabs() {
    final opening = !_showQuickTabs;
    setState(() => _showQuickTabs = opening);
  }

  @override
  void didUpdateWidget(MovableTabShortcut oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible || oldWidget.selectedIndex != widget.selectedIndex) {
      _closeQuickTabs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    const buttonSize = 48.0;
    const anchorSize = MovableTabShortcut.anchorSize;
    const minLeft = SpSpace.s3;
    final maxLeft = math.max(
      minLeft,
      media.size.width - anchorSize - SpSpace.s3,
    );
    final minTop = media.padding.top + SpSpace.s3;
    final maxTop = math.max(
      minTop,
      media.size.height - media.padding.bottom - anchorSize - SpSpace.s3,
    );
    final dock = math.max(widget.dockHeight, media.padding.bottom);
    final left = (_left ?? media.size.width - anchorSize - SpSpace.s3)
        .clamp(minLeft, maxLeft)
        .toDouble();
    final top = (_top ?? media.size.height - dock - anchorSize - SpSpace.s2)
        .clamp(minTop, maxTop)
        .toDouble();
    final tabs = [
      for (var i = 0; i < widget.destinations.length; i++)
        if (i != widget.selectedIndex) i,
    ];
    final (x, y) = _fan(
      onRight: left + anchorSize / 2 > media.size.width / 2,
      nearBottom: top + anchorSize / 2 > media.size.height * 2 / 3,
    );
    const minButtonLeft = SpSpace.s2;
    final maxButtonLeft = math.max(
      minButtonLeft,
      media.size.width - buttonSize - SpSpace.s2,
    );
    final minButtonTop = media.padding.top + SpSpace.s2;
    final maxButtonTop = math.max(
      minButtonTop,
      media.size.height - media.padding.bottom - buttonSize - SpSpace.s2,
    );
    return Positioned.fill(
      key: const ValueKey('movable-shortcut'),
      child: IgnorePointer(
        ignoring: !widget.visible,
        child: AnimatedOpacity(
          key: const ValueKey('shortcut-visibility'),
          opacity: widget.visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOutCubic,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (_showQuickTabs)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closeQuickTabs,
                  ),
                ),
              for (var slot = 0; slot < tabs.length; slot++)
                _placed(
                  tabs[slot],
                  slot,
                  Offset(
                    _clampTo(
                      left + anchorSize / 2 + x[slot] - buttonSize / 2,
                      minButtonLeft,
                      maxButtonLeft,
                    ),
                    _clampTo(
                      top + anchorSize / 2 + y[slot] - buttonSize / 2,
                      minButtonTop,
                      maxButtonTop,
                    ),
                  ),
                  Offset(left + anchorSize / 2, top + anchorSize / 2),
                  buttonSize,
                ),
              Positioned(
                left: left,
                top: top,
                child: AnimatedScale(
                  scale: widget.visible ? 1 : .84,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  child: GestureDetector(
                    onPanUpdate: (details) => setState(() {
                      _left = (left + details.delta.dx).clamp(minLeft, maxLeft);
                      _top = (top + details.delta.dy).clamp(minTop, maxTop);
                    }),
                    child: Tooltip(
                      message: context.strings.shell.tabs,
                      child: FloatingActionButton.small(
                        heroTag: 'quick-tabs-toggle',
                        onPressed: _toggleQuickTabs,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(
                                scale: animation,
                                child: FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                              ),
                          child: AnimatedRotation(
                            turns: _showQuickTabs ? .125 : 0,
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            child: Icon(
                              _showQuickTabs
                                  ? AppIcons.close
                                  : AppIcons.quickTabs,
                              key: ValueKey(_showQuickTabs),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Button offsets from the anchor's centre: a half circle beside it, or a
  /// quarter circle opening upward when it rests low, so no button is pushed
  /// off the bottom onto another.
  (List<double>, List<double>) _fan({
    required bool onRight,
    required bool nearBottom,
  }) {
    final side = onRight ? -1.0 : 1.0;
    if (nearBottom) {
      return (
        [
          for (final dx in const [0.0, 56.0, 97.0, 112.0]) dx * side,
        ],
        const [-112.0, -97.0, -56.0, 0.0],
      );
    }
    return (
      [
        for (final dx in const [86.0, 108.0, 108.0, 86.0]) dx * side,
      ],
      const [-76.0, -28.0, 28.0, 76.0],
    );
  }

  double _clampTo(double value, double min, double max) =>
      value.clamp(min, max).toDouble();

  Widget _placed(
    int index,
    int slot,
    Offset topLeft,
    Offset anchorCentre,
    double buttonSize,
  ) => Positioned(
    left: topLeft.dx,
    top: topLeft.dy,
    child: _tabButton(
      index,
      slot,
      (anchorCentre - (topLeft + Offset(buttonSize / 2, buttonSize / 2))) /
          buttonSize,
    ),
  );

  Widget _tabButton(int index, int slot, Offset originOffset) {
    final visible = _showQuickTabs;
    final (icon, label) = widget.destinations[index];
    return IgnorePointer(
      key: ValueKey('quick-tab-$index'),
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : originOffset,
        duration: Duration(milliseconds: 230 + slot * 45),
        curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
        child: AnimatedScale(
          scale: visible ? 1 : .62,
          duration: Duration(milliseconds: 210 + slot * 40),
          curve: visible ? Curves.easeOutBack : Curves.easeInCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: Duration(milliseconds: 180 + slot * 25),
            curve: Curves.easeInOutCubic,
            child: Tooltip(
              message: label,
              child: FloatingActionButton.small(
                heroTag: 'quick-tab-$index',
                onPressed: () {
                  _closeQuickTabs();
                  widget.onSelect(index);
                },
                child: Icon(icon),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
