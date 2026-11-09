import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stock_pulse/core/observability/presentation/frame_stats.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';

class PerformanceStatsOverlay extends StatefulWidget {
  const PerformanceStatsOverlay({super.key});

  @override
  State<PerformanceStatsOverlay> createState() =>
      _PerformanceStatsOverlayState();
}

class _PerformanceStatsOverlayState extends State<PerformanceStatsOverlay> {
  final _stats = FrameStats();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_stats.recordTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_stats.recordTimings);
    _stats.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _stats,
    builder: (context, _) => DecoratedBox(
      decoration: BoxDecoration(
        color: context.sp.surface2,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Text(
          _stats.summary,
          style: TextStyle(
            color: context.sp.textPrimary,
            fontSize: 11,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ),
  );
}
