import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/observability/data/perf_marks.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/core/storage/application/snapshot_scheduler.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';

/// App hidden → socket paused and snapshot saved; shown → resumed. Prices
/// nobody sees waste battery and data, and the OS suspends background
/// sockets anyway.
class AppLifecycleHost extends ConsumerStatefulWidget {
  const AppLifecycleHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleHost> createState() => _AppLifecycleHostState();
}

class _AppLifecycleHostState extends ConsumerState<AppLifecycleHost> {
  late final AppLifecycleListener _lifecycle;
  late final SnapshotScheduler _scheduler;
  Stopwatch? _resumeFrame;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(pushLinkHandlerProvider).start());
      if (mounted) {
        unawaited(
          _recordOpen('cold', StartupMarks.elapsedSinceMainStartMs ?? 0),
        );
      }
    });
    // A listener, not a read: a provider nobody listens to is paused, and
    // the scheduler must keep hearing network status changes.
    ref.listenManual(restoreSnapshotProvider, (_, _) {});
    _scheduler = ref.listenManual(snapshotSchedulerProvider, (_, _) {}).read()
      ..onShow();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _resumeFrame = Stopwatch()..start();
        ref.read(marketSocketProvider).pause();
        _scheduler.onHide();
      },
      onShow: () {
        ref.read(marketSocketProvider).resume();
        _scheduler.onShow();
        final resume = _resumeFrame;
        if (resume != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              unawaited(_recordOpen('warm', resume.elapsedMilliseconds));
            }
          });
          _resumeFrame = null;
        }
      },
    );
  }

  Future<void> _recordOpen(String launch, int firstFrameMs) async {
    try {
      await ref.read(localPrefsProvider.future);
      ref
          .read(analyticsProvider)
          .log(Events.appOpened(launch: launch, firstFrameMs: firstFrameMs));
    } on Object catch (error, stack) {
      ref
          .read(crashReporterProvider)
          .recordError(error, stack, reason: 'analytics_app_open');
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
