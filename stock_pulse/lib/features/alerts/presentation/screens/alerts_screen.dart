import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/push/di/push_providers.dart';
import 'package:stock_pulse/core/push/domain/push_permission_service.dart';
import 'package:stock_pulse/core/storage/di/storage_providers.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';
import 'package:stock_pulse/core/widgets/error_view.dart';
import 'package:stock_pulse/core/widgets/sp_sheet.dart';
import 'package:stock_pulse/features/alerts/di/alerts_providers.dart';
import 'package:stock_pulse/features/alerts/domain/price_alert.dart';
import 'package:stock_pulse/features/alerts/presentation/widgets/create_alert_form.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings.alerts;
    final state = ref.watch(alertsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      floatingActionButton: switch (state) {
        AsyncData(:final value) when value.isEmpty => null,
        _ => FloatingActionButton(
          tooltip: s.create,
          onPressed: () => _showCreateAlert(context, ref),
          child: const Icon(AppIcons.increase),
        ),
      },
      body: switch (state) {
        AsyncData(:final value) =>
          value.isEmpty
              ? _EmptyAlerts(
                  message: s.empty,
                  onCreate: () => _showCreateAlert(context, ref),
                )
              : ListView(
                  children: [
                    for (final alert in value)
                      ListTile(
                        title: Text(alert.symbol),
                        subtitle: Text(
                          s.conditionPrice(
                            alert.cond == AlertCondition.above
                                ? s.above
                                : s.below,
                            Fmt.price(alert.level),
                          ),
                        ),
                        trailing: alert.status == AlertStatus.active
                            ? IconButton(
                                tooltip: s.cancel,
                                icon: const Icon(AppIcons.clearLog),
                                onPressed: () async {
                                  await ref
                                      .read(alertsControllerProvider.notifier)
                                      .cancel(alert.alertId);
                                },
                              )
                            : Text(alert.status.name),
                      ),
                  ],
                ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () async => ref.invalidate(alertsControllerProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

void _showCreateAlert(BuildContext context, WidgetRef ref) => showSpSheet<void>(
  context,
  builder: (_) =>
      CreateAlertForm(onCreated: () => _askForNotifications(context, ref)),
);

Future<void> _askForNotifications(BuildContext context, WidgetRef ref) async {
  final prefs = await ref.read(localPrefsProvider.future);
  if (!context.mounted || prefs.data.notificationExplainerShown) return;
  await prefs.update((data) => data.copyWith(notificationExplainerShown: true));
  if (!context.mounted) return;
  final strings = context.strings.more;
  final enable = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(strings.notifications),
      content: Text(strings.notificationAlertExplanation),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(strings.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(strings.enableNotifications),
        ),
      ],
    ),
  );
  if (enable == true && context.mounted) {
    final service = ref.read(pushPermissionServiceProvider);
    if (await service.status() == PushPermissionStatus.notDetermined) {
      await service.request();
    }
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts({required this.message, required this.onCreate});
  final String message;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Padding(
        padding: const EdgeInsets.all(SpSpace.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.sp.infoTint,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(SpSpace.s4),
                child: Icon(AppIcons.time),
              ),
            ),
            const SizedBox(height: SpSpace.s4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: context.sp.textSecondary),
            ),
            const SizedBox(height: SpSpace.s4),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(AppIcons.increase),
              label: Text(context.strings.alerts.create),
            ),
          ],
        ),
      ),
    ),
  );
}
