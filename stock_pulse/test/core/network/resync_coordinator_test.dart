import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:stock_pulse/core/network/data/resync_coordinator.dart';

void main() {
  test(
    'coalesces gaps and reloads registered repositories on reconnect',
    () async {
      final reload = Completer<void>();
      var sent = 0;
      var reloads = 0;
      var starts = 0;
      var completions = 0;
      final coordinator = ResyncCoordinator(() => sent++);
      final started = coordinator.started.listen((_) => starts++);
      final completed = coordinator.completed.listen((_) => completions++);
      final unregister = coordinator.register(() {
        reloads++;
        return reload.future;
      });

      final first = coordinator.onGap();
      expect(coordinator.isRunning, isTrue);
      expect(identical(first, coordinator.onGap()), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect((sent, reloads, starts), (1, 1, 1));
      reload.complete();
      await first;
      await Future<void>.delayed(Duration.zero);
      expect((coordinator.isRunning, completions), (false, 1));

      unregister();
      await coordinator.onReconnect();
      await Future<void>.delayed(Duration.zero);
      expect((sent, reloads, completions), (1, 1, 2));
      await coordinator.dispose();
      await started.cancel();
      await completed.cancel();
    },
  );
}
