/// Every screen whose visibility matters for live data.
///
/// The first five are the shell tabs, in bar order; the rest are routes on
/// the root navigator. A route's `name` is `ScreenId.x.name`, which is how
/// `VisibilityRouteObserver` maps a route back to its id.
enum ScreenId {
  watchlist,
  options,
  ai,
  portfolio,
  more,
  stockDetail,
  strategy,
  alerts,
}

/// Shell tabs in bar order: branch index == position in this list.
const kTabs = [
  ScreenId.watchlist,
  ScreenId.options,
  ScreenId.ai,
  ScreenId.portfolio,
  ScreenId.more,
];

/// `RouteSettings.name` of the shell's page on the root navigator. The
/// visibility observer never counts it as a cover.
const kShellPageName = 'shell';
