import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/core/theme/sp_theme_x.dart';
import 'package:stock_pulse/core/theme/sp_tokens.dart';

/// `● Live` / `● Reconnecting` / `⚠ Offline`. Reconnecting
/// and Offline are `warn`, never red (red means price direction). The text
/// always names the state.
class ConnectionBadge extends ConsumerWidget {
  const ConnectionBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sp = context.sp;
    final strings = context.strings.common;
    final status = ref.watch(networkStatusProvider).value;
    final (label, dot, text) = switch (status) {
      NetworkStatus.live => (
        strings.connectionLive,
        sp.accent,
        sp.textSecondary,
      ),
      NetworkStatus.reconnecting ||
      null => (strings.connectionReconnecting, sp.warn, sp.warn),
      NetworkStatus.delayed => (strings.connectionDelayed, sp.warn, sp.warn),
      NetworkStatus.offline => (strings.connectionOffline, sp.warn, sp.warn),
    };
    return Semantics(
      label: strings.connectionSemantics(label),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SpSpace.s3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (status == NetworkStatus.offline)
                Icon(AppIcons.offline, size: 14, color: dot)
              else
                DecoratedBox(
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                  child: const SizedBox.square(dimension: 8),
                ),
              const SizedBox(width: SpSpace.s1),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
