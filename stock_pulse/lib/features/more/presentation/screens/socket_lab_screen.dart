import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/core/assets/app_icons.dart';
import 'package:stock_pulse/core/format/formatters.dart';
import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/core/widgets/connection_badge.dart';
import 'package:stock_pulse/features/more/di/more_providers.dart';
import 'package:stock_pulse/features/more/presentation/widgets/chaos_buttons.dart';
import 'package:stock_pulse/features/more/presentation/widgets/frame_tile.dart';
import 'package:stock_pulse/features/more/presentation/widgets/socket_status_text.dart';

/// The WebSocket at work: connection state, every raw frame in and out, and
/// buttons that break the connection on purpose.
class SocketLabScreen extends ConsumerWidget {
  const SocketLabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lab = ref.watch(socketLabControllerProvider);
    final controller = ref.read(socketLabControllerProvider.notifier);
    final strings = context.strings.more;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.socketLab),
        actions: [
          IconButton(
            tooltip: lab.paused ? strings.resumeLog : strings.pauseLog,
            icon: Icon(lab.paused ? AppIcons.play : AppIcons.pause),
            onPressed: controller.togglePause,
          ),
          IconButton(
            tooltip: strings.clearLog,
            icon: const Icon(AppIcons.clearLog),
            onPressed: controller.clear,
          ),
          const ConnectionBadge(),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SocketStatusText(),
                const SizedBox(height: 4),
                Text(
                  strings.traffic(
                    lab.received,
                    Fmt.compact(lab.bytesIn),
                    lab.sent,
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                const ChaosButtons(),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: lab.frames.length,
              itemBuilder: (_, i) => FrameTile(frame: lab.frames[i]),
            ),
          ),
        ],
      ),
    );
  }
}
