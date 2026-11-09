import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/app/router/app_route.dart';
import 'package:stock_pulse/app/router/navigation.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/alerts/di/alert_queue_providers.dart';
import 'package:stock_pulse/features/more/presentation/widgets/settings_toggles.dart';

/// The More tab root; settings and developer screens hang off it.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.more;
    final hasTriggeredAlert = ref.watch(alertQueueProvider).isNotEmpty;
    final alertStrings = context.strings.alerts;
    return Scaffold(
      appBar: AppBar(title: Text(strings.title)),
      body: ListView(
        children: [
          const SettingsToggles(),
          ListTile(
            leading: Semantics(
              label: hasTriggeredAlert
                  ? alertStrings.triggeredAlert
                  : alertStrings.title,
              child: ExcludeSemantics(
                child: Badge(
                  isLabelVisible: hasTriggeredAlert,
                  smallSize: 8,
                  child: const Icon(AppIcons.notifications),
                ),
              ),
            ),
            title: Text(context.strings.alerts.title),
            onTap: () => context.pushTo<void>(const AlertsRoute()),
          ),
          ListTile(
            leading: const Icon(AppIcons.increase),
            title: Text(strings.addFunds),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => context.pushTo<void>(const AddFundsRoute()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              strings.developer,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ListTile(
            leading: const Icon(AppIcons.time),
            title: Text(strings.debugClock),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => context.pushTo<void>(const DebugClockRoute()),
          ),
          ListTile(
            leading: const Icon(AppIcons.socketLab),
            title: Text(strings.socketLab),
            trailing: const Icon(AppIcons.chevronRight),
            onTap: () => context.pushTo<void>(const SocketLabRoute()),
          ),
        ],
      ),
    );
  }
}
