import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_kind.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_series.dart';
import 'package:stock_pulse/features/chart/domain/indicators/study_spec.dart';
import 'package:stock_pulse/features/chart/presentation/studies/study_painter.dart';

class StudyPaneStack extends StatefulWidget {
  const StudyPaneStack({
    super.key,
    required this.series,
    this.maxPaneHeight = 160,
  });
  final Map<StudySpec, StudySeries> series;
  final double maxPaneHeight;
  @override
  State<StudyPaneStack> createState() => _StudyPaneStackState();
}

class _StudyPaneStackState extends State<StudyPaneStack> {
  double _paneHeight = 80;

  @override
  Widget build(BuildContext context) {
    final panes = widget.series.entries
        .where(
          (e) =>
              (e.key.kind == StudyKind.rsi || e.key.kind == StudyKind.macd) &&
              e.value.lines.isNotEmpty,
        )
        .toList();
    if (panes.isEmpty) return const SizedBox.shrink();
    final sp = context.sp;
    final paneHeight = _paneHeight
        .clamp(64.0, math.max(64, widget.maxPaneHeight))
        .toDouble();
    return SizedBox(
      height: (panes.length * (paneHeight + 12)).toDouble(),
      child: Column(
        children: [
          for (var index = 0; index < panes.length; index++) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (details) {
                setState(() {
                  _paneHeight = (_paneHeight + details.delta.dy)
                      .clamp(64.0, math.max(64, widget.maxPaneHeight))
                      .toDouble();
                });
              },
              child: SizedBox(
                height: 12,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 3,
                    decoration: BoxDecoration(
                      color: sp.outline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: paneHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: StudyPainter(
                        lines: panes[index].value.lines.values.toList(),
                        start: 0,
                        end: panes[index].value.lines.values.first.length,
                        width: 1,
                        low: panes[index].key.kind == StudyKind.rsi
                            ? 0
                            : _min(panes[index].value),
                        high: panes[index].key.kind == StudyKind.rsi
                            ? 100
                            : _max(panes[index].value),
                        colors: [sp.accent, sp.warn, sp.info],
                        histogram: panes[index].key.kind == StudyKind.macd,
                        guides: panes[index].key.kind == StudyKind.rsi
                            ? const [30, 70]
                            : const [],
                      ),
                    ),
                  ),
                  Text(
                    '${context.strings.studies.name(panes[index].key.kind.name)} (${panes[index].key.period})',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _min(StudySeries s) =>
      [
        0.0,
        ...s.lines.values.expand((v) => v).whereType<double>(),
      ].reduce(math.min) -
      .01;
  double _max(StudySeries s) =>
      [
        0.0,
        ...s.lines.values.expand((v) => v).whereType<double>(),
      ].reduce(math.max) +
      .01;
}
