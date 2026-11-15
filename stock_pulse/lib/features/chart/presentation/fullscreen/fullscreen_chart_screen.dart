import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/widgets/connection_badge.dart';
import 'package:stock_pulse/core/widgets/error_view.dart';
import 'package:stock_pulse/core/widgets/sheet_placement_scope.dart';
import 'package:stock_pulse/features/chart/di/chart_providers.dart';
import 'package:stock_pulse/features/chart/presentation/chart_view.dart';
import 'package:stock_pulse/features/chart/presentation/fullscreen/chart_rail.dart';
import 'package:stock_pulse/features/market/di/market_providers.dart';
import 'package:stock_pulse/features/market/presentation/widgets/range_bar.dart';

class FullscreenChartScreen extends ConsumerStatefulWidget {
  const FullscreenChartScreen({super.key, required this.instrumentId});
  final String instrumentId;
  @override
  ConsumerState<FullscreenChartScreen> createState() =>
      _FullscreenChartScreenState();
}

class _FullscreenChartScreenState extends ConsumerState<FullscreenChartScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(chartControllerProvider(widget.instrumentId).notifier)
            .openedFullscreen();
      }
    });
  }

  @override
  void dispose() {
    unawaited(
      // Every orientation again: tablets and unfolded foldables rotate
      // freely outside the full-screen chart.
      SystemChrome.setPreferredOrientations(DeviceOrientation.values),
    );
    super.dispose();
  }

  void _exit() {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      context.goTo(StockRoute(widget.instrumentId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = stockDetailControllerProvider(widget.instrumentId);
    final data = ref.watch(provider.select((s) => (s.hasValue, s.error)));
    return SheetPlacementScope(
      child: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              ChartRail(instrumentId: widget.instrumentId, onExit: _exit),
              Expanded(
                child: switch (data) {
                  (true, _) => Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(widget.instrumentId)),
                          const ConnectionBadge(),
                        ],
                      ),
                      Expanded(
                        child: ChartView(instrumentId: widget.instrumentId),
                      ),
                      RangeBar(instrumentId: widget.instrumentId),
                    ],
                  ),
                  (_, final Object error) => ErrorView(
                    error: error,
                    onRetry: () => ref.read(provider.notifier).retry(),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
