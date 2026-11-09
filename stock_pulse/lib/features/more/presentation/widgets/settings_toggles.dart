import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/observability/di/observability_providers.dart';
import 'package:stock_pulse/features/more/di/settings_providers.dart';
import 'package:stock_pulse/features/more/presentation/settings/notifications_row.dart';

class SettingsToggles extends ConsumerWidget {
  const SettingsToggles({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(settingsControllerProvider).value;
    final controller = ref.read(settingsControllerProvider.notifier);
    final showOverlay = ref.watch(debugOverlayProvider);
    final s = context.strings.more;
    return Column(
      children: [
        SwitchListTile(
          title: Text(s.haptics),
          value: prefs?.hapticsEnabled ?? false,
          onChanged: prefs == null
              ? null
              : (enabled) => controller.setHaptics(enabled: enabled),
        ),
        SwitchListTile(
          title: Text(s.analytics),
          value: prefs?.analyticsConsent ?? false,
          onChanged: prefs == null
              ? null
              : (enabled) => controller.setAnalytics(enabled: enabled),
        ),
        const NotificationsRow(),
        if (!kReleaseMode)
          SwitchListTile(
            title: Text(s.debugOverlay),
            value: showOverlay,
            onChanged: (enabled) => ref
                .read(debugOverlayProvider.notifier)
                .setEnabled(enabled: enabled),
          ),
      ],
    );
  }
}
