import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/market_time/di/market_time_providers.dart';
import 'package:stock_pulse/core/network/di/network_status_provider.dart';
import 'package:stock_pulse/core/network/domain/network_status.dart';
import 'package:stock_pulse/features/more/di/demo_providers.dart';

class DebugClockScreen extends ConsumerWidget {
  const DebugClockScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings.more;
    final state = ref.watch(demoControllerProvider);
    final market = ref.watch(marketClockProvider).value;
    final offline =
        ref.watch(networkStatusProvider).value == NetworkStatus.offline;
    final now = ref.watch(serverClockProvider).now();
    final date = market?.marketNow(now) ?? now;
    final ist = date.add(const Duration(hours: 5, minutes: 30));
    return Scaffold(
      appBar: AppBar(title: Text(s.debugClock)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(s.clockExplanation),
          if (state.hasError) Text(s.clockFailed),
          if (offline)
            ListTile(
              enabled: false,
              leading: const Icon(AppIcons.offline),
              title: Text(s.needsConnection),
            ),
          for (final (hour, minute, second) in [
            (9, 14, 50),
            (9, 15, 0),
            (15, 19, 50),
            (15, 30, 0),
          ])
            ListTile(
              title: Text(Fmt.time(DateTime(2000, 1, 1, hour, minute, second))),
              enabled: !state.isLoading && !offline,
              onTap: () async {
                final target = DateTime.utc(
                  ist.year,
                  ist.month,
                  ist.day,
                  hour,
                  minute,
                  second,
                ).subtract(const Duration(hours: 5, minutes: 30));
                if (target.isBefore(date)) {
                  final accepted = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(s.resetDemo),
                      content: Text(s.backwardReset),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(s.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(s.resetDemo),
                        ),
                      ],
                    ),
                  );
                  if (accepted == true) {
                    await ref
                        .read(demoControllerProvider.notifier)
                        .reset(time: target);
                  }
                } else {
                  await ref
                      .read(demoControllerProvider.notifier)
                      .setClock(target);
                }
              },
            ),
        ],
      ),
    );
  }
}
