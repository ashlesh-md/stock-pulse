import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/core/visibility/application/covered_state_notifier.dart';
import 'package:stock_pulse/core/visibility/application/screen_visibility.dart';
import 'package:stock_pulse/core/visibility/application/selected_tab.dart';
import 'package:stock_pulse/core/visibility/domain/covered_state.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, ScreenId>(
  SelectedTabNotifier.new,
);

final coveredStateProvider =
    NotifierProvider<CoveredStateNotifier, CoveredState>(
      CoveredStateNotifier.new,
    );

/// Price controllers `ref.listen` to this and hold a repository stream only
/// while it is true. App lifecycle is not part of it: pausing the socket
/// already releases every server subscription.
final screenVisibleProvider = Provider.family<bool, ScreenId>(
  (ref, id) => isScreenVisible(
    id,
    ref.watch(selectedTabProvider),
    ref.watch(coveredStateProvider),
  ),
);
