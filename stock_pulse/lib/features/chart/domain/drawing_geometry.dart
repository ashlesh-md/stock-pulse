import 'package:flutter/foundation.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';

/// Converts persisted time/price anchors to a chart viewport and back.
@immutable
class DrawingGeometry {
  DrawingGeometry({
    required this.first,
    required this.last,
    required this.low,
    required this.high,
    required this.width,
    required this.height,
  }) {
    if (!last.isAfter(first) ||
        !low.isFinite ||
        !high.isFinite ||
        high <= low ||
        !width.isFinite ||
        !height.isFinite ||
        width <= 0 ||
        height <= 0) {
      throw ArgumentError('Drawing viewport must have positive finite bounds');
    }
  }

  final DateTime first;
  final DateTime last;
  final double low;
  final double high;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is DrawingGeometry &&
      other.first == first &&
      other.last == last &&
      other.low == low &&
      other.high == high &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(first, last, low, high, width, height);

  (double, double) project(DrawingAnchor anchor) => (
    anchor.time.difference(first).inMicroseconds /
        last.difference(first).inMicroseconds *
        width,
    (high - anchor.price) / (high - low) * height,
  );

  DrawingAnchor unproject(double x, double y) =>
      DrawingAnchor(time: first.add(timeDelta(x)), price: high + priceDelta(y));

  Duration timeDelta(double dx) => Duration(
    microseconds: (dx / width * last.difference(first).inMicroseconds).round(),
  );

  double priceDelta(double dy) => -dy / height * (high - low);
}
