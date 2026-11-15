import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/features/chart/di/drawings_providers.dart';
import 'package:stock_pulse/features/chart/domain/drawing.dart';
import 'package:stock_pulse/features/chart/domain/drawing_geometry.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_handle.dart';
import 'package:stock_pulse/features/chart/presentation/drawings/drawing_painter.dart';

class DrawingLayer extends ConsumerWidget {
  const DrawingLayer({
    super.key,
    required this.instrumentId,
    required this.geometry,
    required this.tickSize,
  });
  final String instrumentId;
  final DrawingGeometry geometry;
  final double tickSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(drawingsControllerProvider(instrumentId));
    final controller = ref.read(
      drawingsControllerProvider(instrumentId).notifier,
    );
    final colors = context.sp;
    Offset project(DrawingAnchor a) {
      final (x, y) = geometry.project(a);
      return Offset(x, y);
    }

    void moveHandle(Drawing d, Offset delta, {required bool end}) {
      final a = end ? d.end! : d.start;
      final position = project(a) + delta;
      controller.moveHandle(
        d.id,
        end: end,
        anchor: geometry.unproject(position.dx, position.dy),
        tickSize: tickSize,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        for (final drawing in state.drawings) ...[
          GestureDetector(
            onTap: () => controller.select(drawing.id),
            onPanUpdate: (d) => controller.moveBody(
              drawing.id,
              timeDelta: geometry.timeDelta(d.delta.dx),
              priceDelta: geometry.priceDelta(d.delta.dy),
              tickSize: tickSize,
            ),
            child: CustomPaint(
              painter: DrawingPainter(
                drawing: drawing,
                geometry: geometry,
                color: colors.accent,
                labelColor: colors.textPrimary,
              ),
            ),
          ),
          if (state.selectedId == drawing.id) ...[
            DrawingHandle(
              position: project(drawing.start),
              color: colors.accent,
              onDrag: (delta) => moveHandle(drawing, delta, end: false),
            ),
            if (drawing.end != null)
              DrawingHandle(
                position: project(drawing.end!),
                color: colors.accent,
                onDrag: (delta) => moveHandle(drawing, delta, end: true),
              ),
          ],
        ],
        if (state.mode != null && !state.atLimit)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => controller.place(
              geometry.unproject(d.localPosition.dx, d.localPosition.dy),
              tickSize: tickSize,
            ),
          ),
      ],
    );
  }
}
