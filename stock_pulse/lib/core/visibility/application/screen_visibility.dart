import 'package:stock_pulse/core/visibility/domain/covered_state.dart';
import 'package:stock_pulse/core/visibility/domain/screen_id.dart';

/// True while screen [id] is on screen: a tab when it is [selected] and no
/// opaque route covers the shell; a routed screen when it is the top opaque
/// route.
///
/// The key is the enum, so two stacked `stockDetail` pages would both read
/// true; `StockRoute` replaces a stock page on top instead of stacking one.
bool isScreenVisible(ScreenId id, ScreenId selected, CoveredState covered) {
  if (kTabs.contains(id)) return covered.opaqueDepth == 0 && selected == id;
  return covered.topOpaque == id;
}
