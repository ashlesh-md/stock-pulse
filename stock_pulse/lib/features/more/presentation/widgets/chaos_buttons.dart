import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/core/l10n/l10n_context.dart';
import 'package:stock_pulse/features/more/application/chaos_text.dart';
import 'package:stock_pulse/features/more/di/more_providers.dart';
import 'package:stock_pulse/features/more/domain/chaos.dart';

/// One button per [Chaos]; the tooltip says what the server will do.
class ChaosButtons extends ConsumerWidget {
  const ChaosButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings.more;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chaos in Chaos.values)
          Tooltip(
            message: chaosExplanation(strings, chaos),
            child: OutlinedButton(
              onPressed: () =>
                  ref.read(socketLabControllerProvider.notifier).trigger(chaos),
              child: Text(chaosLabel(strings, chaos)),
            ),
          ),
      ],
    );
  }
}
