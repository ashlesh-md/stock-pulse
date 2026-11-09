import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/di/app_providers.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/analytics/di/analytics_providers.dart';
import 'package:stock_pulse/core/analytics/domain/analytics_events.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/alerts/di/alert_queue_providers.dart';

/// Shows the oldest triggered alert as a banner above every route, except
/// while a sheet is open.
class AlertBannerHost extends ConsumerWidget {
  const AlertBannerHost({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(alertQueueProvider);
    final sheetOpen = ref.watch(openSheetCountProvider) > 0;
    final alert = queue.firstOrNull;
    final shown = alert != null && !sheetOpen;
    final s = context.strings.alerts;
    return Column(
      children: [
        if (alert != null && !sheetOpen)
          SafeArea(
            bottom: false,
            child: MaterialBanner(
              content: Text(
                s.triggered(
                  alert.symbol,
                  Fmt.price(alert.triggerLtp ?? alert.level),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      ref.read(alertQueueProvider.notifier).dismiss(),
                  child: Text(s.dismiss),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(alertQueueProvider.notifier).dismiss();
                    ref.read(analyticsProvider).log(Events.alertOpened());
                    ref.read(goRouterProvider).goTo(StockRoute(alert.symbol));
                  },
                  child: Text(s.view),
                ),
              ],
            ),
          ),
        Expanded(
          key: const ValueKey('alertHostChild'),
          // The banner already took the status-bar inset.
          child: MediaQuery.removePadding(
            context: context,
            removeTop: shown,
            child: child,
          ),
        ),
      ],
    );
  }
}
