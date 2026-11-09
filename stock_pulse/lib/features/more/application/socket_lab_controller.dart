import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_pulse/core/error/result.dart';
import 'package:stock_pulse/core/feedback/di/feedback_providers.dart';
import 'package:stock_pulse/core/feedback/domain/feedback_message.dart';
import 'package:stock_pulse/core/l10n/di/l10n_providers.dart';
import 'package:stock_pulse/core/l10n/strings/error_strings.dart';
import 'package:stock_pulse/core/network/di/network_providers.dart';
import 'package:stock_pulse/core/network/domain/socket_status.dart';
import 'package:stock_pulse/features/more/application/chaos_text.dart';
import 'package:stock_pulse/features/more/application/socket_lab_state.dart';
import 'package:stock_pulse/features/more/di/more_data_providers.dart';
import 'package:stock_pulse/features/more/domain/chaos.dart';

class SocketLabController extends Notifier<SocketLabState> {
  @override
  SocketLabState build() {
    final sub = ref.watch(marketSocketProvider).frames.listen(_onFrame);
    ref.onDispose(sub.cancel);
    return const SocketLabState();
  }

  void _onFrame(SocketFrame frame) {
    final s = state;
    state = s.copyWith(
      received: s.received + (frame.outgoing ? 0 : 1),
      sent: s.sent + (frame.outgoing ? 1 : 0),
      bytesIn: s.bytesIn + (frame.outgoing ? 0 : frame.text.length),
      frames: s.paused
          ? null
          : [frame, ...s.frames.take(SocketLabState.maxFrames - 1)],
    );
  }

  void togglePause() => state = state.copyWith(paused: !state.paused);

  void clear() => state = state.copyWith(frames: const []);

  /// Shows what the server will do, or why it refused.
  Future<void> trigger(Chaos chaos) async {
    final result = await ref.read(chaosTriggerProvider).trigger(chaos);
    if (!ref.mounted) return;
    final strings = ref.read(stringsProvider);
    ref.read(feedbackControllerProvider.notifier).show(switch (result) {
      Success() => FeedbackMessage(
        key: 'socketLab.chaos.${chaos.name}',
        text: chaosExplanation(strings.more, chaos),
      ),
      Failure(:final error) => FeedbackMessage(
        key: 'socketLab.failed.${chaos.name}',
        text: errorText(strings.errors, error),
        kind: FeedbackKind.error,
      ),
    });
  }
}
