import 'package:flutter/widgets.dart';
import 'package:stock_pulse/app/layout/fold_split.dart';

/// The three window sizes every layout decision keys off.
///
/// compact < 600 dp (phones), medium 600–1024 dp (tablets, narrow desktop
/// windows), expanded ≥ 1024 dp (desktop, web, landscape tablets).
enum WindowClass {
  compact,
  medium,
  expanded;

  static const mediumMin = 600.0;
  static const expandedMin = 1024.0;
  static const compactRailRegionWidth = 73.0;
  static const expandedRailRegionWidth = 201.0;

  static WindowClass fromWidth(double width) => switch (width) {
    < mediumMin => compact,
    < expandedMin => medium,
    _ => expanded,
  };

  bool get usesRail => this != compact;
  bool get showsTwoPanes => this == expanded;

  double get railRegionWidth => switch (this) {
    compact => 0,
    medium => compactRailRegionWidth,
    expanded => expandedRailRegionWidth,
  };
}

/// Content width caps, so lists and forms do not stretch across a desktop
/// window.
abstract final class ContentWidth {
  /// Lists and settings screens.
  static const list = 840.0;

  /// Tables such as the option chain.
  static const table = 1280.0;

  /// Forms such as Add funds.
  static const form = 560.0;

  /// The list pane of a two-pane layout.
  static const listPane = 400.0;
}

extension WindowClassContext on BuildContext {
  /// The window class of the whole window, not of the parent's constraints,
  /// so every widget on screen agrees on it.
  WindowClass get windowClass =>
      WindowClass.fromWidth(MediaQuery.sizeOf(this).width);

  /// True when a list and its detail sit side by side: an expanded window,
  /// or a foldable whose hinge splits the screen at any width.
  bool get showsDetailPane =>
      windowClass.showsTwoPanes ||
      foldSplitOf(
            MediaQuery.displayFeaturesOf(this),
            MediaQuery.sizeOf(this),
          ) !=
          null;
}
