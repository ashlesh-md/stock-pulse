import 'package:flutter/foundation.dart';

/// A price/time anchor used by persistent chart drawings.
@immutable
class DrawingAnchor {
  const DrawingAnchor({required this.time, required this.price});

  final DateTime time;
  final double price;

  Map<String, Object?> toJson() => {
    'time': time.toUtc().millisecondsSinceEpoch,
    'price': price,
  };

  factory DrawingAnchor.fromJson(Map<String, Object?> json) => DrawingAnchor(
    time: DateTime.fromMillisecondsSinceEpoch(
      json['time']! as int,
      isUtc: true,
    ),
    price: (json['price']! as num).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is DrawingAnchor && other.time == time && other.price == price;

  @override
  int get hashCode => Object.hash(time, price);
}

enum DrawingKind { horizontal, trendLine, fibRetracement }

/// A chart annotation. Horizontal lines use [start] only; two-anchor kinds
/// also have [end].
@immutable
class Drawing {
  const Drawing({
    required this.id,
    required this.kind,
    required this.start,
    this.end,
  });

  final String id;
  final DrawingKind kind;
  final DrawingAnchor start;
  final DrawingAnchor? end;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'start': start.toJson(),
    'end': end?.toJson(),
  };

  factory Drawing.fromJson(Map<String, Object?> json) => Drawing(
    id: json['id']! as String,
    kind: DrawingKind.values.byName(json['kind']! as String),
    start: DrawingAnchor.fromJson(
      Map<String, Object?>.from(json['start']! as Map),
    ),
    end: json['end'] == null
        ? null
        : DrawingAnchor.fromJson(
            Map<String, Object?>.from(json['end']! as Map),
          ),
  );

  @override
  bool operator ==(Object other) =>
      other is Drawing &&
      other.id == id &&
      other.kind == kind &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(id, kind, start, end);
}
