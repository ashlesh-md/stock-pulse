import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

/// Where a foldable's hinge splits [size] into two panes, if it does.
///
/// A full-height fold or hinge splits left and right (book posture). A
/// full-width one splits top and bottom only while half opened (tabletop).
/// [offset] is the area's position in the window, so bounds come back in the
/// area's own coordinates.
({Axis axis, Rect bounds})? foldSplitOf(
  List<DisplayFeature> features,
  Size size, {
  Offset offset = Offset.zero,
}) {
  for (final feature in features) {
    if (feature.type != DisplayFeatureType.hinge &&
        feature.type != DisplayFeatureType.fold) {
      continue;
    }
    final bounds = feature.bounds.shift(-offset);
    final vertical =
        bounds.height >= size.height * .8 &&
        bounds.left > 0 &&
        bounds.right < size.width;
    if (vertical) return (axis: Axis.horizontal, bounds: bounds);
    final tabletop =
        feature.state == DisplayFeatureState.postureHalfOpened &&
        bounds.width >= size.width * .8 &&
        bounds.top > 0 &&
        bounds.bottom < size.height;
    if (tabletop) return (axis: Axis.vertical, bounds: bounds);
  }
  return null;
}
