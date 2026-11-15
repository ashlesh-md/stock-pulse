import 'package:flutter/material.dart';

class DrawingHandle extends StatelessWidget {
  const DrawingHandle({
    super.key,
    required this.position,
    required this.color,
    required this.onDrag,
  });
  final Offset position;
  final Color color;
  final ValueChanged<Offset> onDrag;
  @override
  Widget build(BuildContext context) => Positioned(
    left: position.dx - 22,
    top: position.dy - 22,
    width: 44,
    height: 44,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: (details) => onDrag(details.delta),
      child: Center(
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    ),
  );
}
