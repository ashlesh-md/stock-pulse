import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/core/visibility/domain/screen_id.dart';

/// Mirror of the router shell's current branch. The router is the source of
/// truth; `AppShellScaffold` is the only writer, after the frame in which
/// the branch changed (a provider may not change during build).
class SelectedTabNotifier extends Notifier<ScreenId> {
  @override
  ScreenId build() => ScreenId.watchlist;

  /// Throws [RangeError] for an index outside [kTabs].
  void mirror(int branchIndex) => state = kTabs[branchIndex];
}
