import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:stock_pulse/core/visibility/domain/covered_state.dart';

/// Written only by `VisibilityRouteObserver`.
class CoveredStateNotifier extends Notifier<CoveredState> {
  @override
  CoveredState build() => CoveredState.shell;

  void set(CoveredState next) => state = next;
}
