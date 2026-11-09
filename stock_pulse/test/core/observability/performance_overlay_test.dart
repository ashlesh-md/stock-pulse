import 'dart:ui' show FrameTiming;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/observability/presentation/frame_stats.dart';
import 'package:stock_pulse/core/observability/presentation/performance_overlay_host.dart';
import 'package:stock_pulse/core/observability/presentation/performance_stats_overlay.dart';

import '../../helpers/sp_app.dart';

void main() {
  test('frame stats calculate rolling FPS, build, and raster averages', () {
    final stats = FrameStats();
    expect(stats.framesPerSecond, isNull);
    expect(stats.summary, '— FPS · Build — ms · Raster — ms');

    final emptyDuration = FrameStats()
      ..recordFrame(
        total: Duration.zero,
        build: Duration.zero,
        raster: Duration.zero,
      );
    expect(emptyDuration.framesPerSecond, isNull);
    emptyDuration.dispose();

    for (var i = 0; i < 60; i++) {
      stats.recordFrame(
        total: const Duration(microseconds: 16667),
        build: const Duration(milliseconds: 2),
        raster: const Duration(milliseconds: 4),
      );
    }

    expect(stats.framesPerSecond, 60);
    expect(stats.averageBuildMs, 2);
    expect(stats.averageRasterMs, 4);
    expect(stats.summary, '60 FPS · Build 2.0 ms · Raster 4.0 ms');

    stats
      ..recordFrame(
        total: const Duration(milliseconds: 100),
        build: const Duration(milliseconds: 20),
        raster: const Duration(milliseconds: 20),
      )
      ..recordFrame(
        total: const Duration(milliseconds: 10),
        build: const Duration(milliseconds: 1),
        raster: const Duration(milliseconds: 1),
      );
    expect(stats.framesPerSecond, 56);
    expect(stats.averageBuildMs, closeTo(2.283, 0.001));
    stats.dispose();

    final fromTiming = FrameStats()
      ..recordTimings([
        FrameTiming(
          vsyncStart: 0,
          buildStart: 1000,
          buildFinish: 3000,
          rasterStart: 3000,
          rasterFinish: 6000,
          rasterFinishWallTime: 6000,
          frameNumber: 1,
        ),
      ]);
    expect(fromTiming.averageBuildMs, 2);
    expect(fromTiming.averageRasterMs, 3);
    fromTiming.dispose();
  });

  testWidgets('the host shows the stats widget only when enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      spApp(
        const PerformanceOverlayHost(enabled: false, child: SizedBox.expand()),
      ),
    );
    expect(find.byType(PerformanceStatsOverlay), findsNothing);

    await tester.pumpWidget(
      spApp(
        const PerformanceOverlayHost(enabled: true, child: SizedBox.expand()),
      ),
    );
    expect(find.byType(PerformanceStatsOverlay), findsOneWidget);
    expect(find.textContaining('FPS'), findsOneWidget);
  });
}
