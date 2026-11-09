import 'package:flutter/material.dart';
import 'package:stock_pulse/core/observability/presentation/performance_stats_overlay.dart';

class PerformanceOverlayHost extends StatelessWidget {
  const PerformanceOverlayHost({
    super.key,
    required this.enabled,
    required this.child,
  });

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      if (enabled)
        const Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              minimum: EdgeInsets.all(8),
              child: Align(
                alignment: Alignment.topRight,
                child: PerformanceStatsOverlay(),
              ),
            ),
          ),
        ),
    ],
  );
}
