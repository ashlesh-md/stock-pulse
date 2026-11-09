# ADR-0015: go_router replaces the custom navigator (reverses TRD v1.0 §1 "No go_router")

Status: accepted · Date: 2026-11-07 · Refs: CR-1.15; TR-12, TR-13, TR-32; ADR-0004 (kept), ADR-0016 (deep links, push)
Reverses: TRD v1.0 §1 Navigation row and §1.1 "Rejected: go_router"; HLD v1.1 D1 and D4 mechanics.

## Context
v1.1 chose Material `Navigator` with one `rootNavigatorKey`, typed opener functions, a hand-built lazy `AppShell` and an
`AppShellController` for the tab, because "no URLs or deep links are in scope". CR-1.15 puts deep links and push
notifications in scope. A notification tap or a link must land on a screen from a URL, with the right tab selected and
the stack rebuilt; the custom navigator cannot do that without writing a router. **This reverses our earlier decision; the
reason it changed is the new scope, not a flaw found in the old design.**

## Options
1. Keep `Navigator` 1.0 and parse links by hand into opener calls.
2. Flutter `Router` API with our own `RouterDelegate` and `RouteInformationParser`.
3. **`go_router` ^18.1.2** (Flutter team package, no codegen; `go_router_builder` is not used).
4. `auto_route` (code generation: rejected by NFR-18).

## Decision
Option 3. Router owner: dev-perf (`lib/app/router/`); each feature owns its routes file.

**Route table** (route `name` = `ScreenId.x.name`, so `VisibilityRouteObserver` and `screenVisibleProvider` keep their keys):
| Path | Name | Navigator | Builds | Owner |
|---|---|---|---|---|
| `/` | — | — | redirect → `/watchlist` | dev-perf |
| `/watchlist` | `watchlist` | shell branch 0 | `WatchlistScreen` | dev-trading |
| `/options?u=&e=&k=&r=` | `options` | shell branch 1 | `ChainScreen(target: ChainArgs.fromQuery(q))` | dev-trading |
| `/ai` | `ai` | shell branch 2 | `AiChatScreen` | dev-ai |
| `/portfolio?tab=positions\|holdings\|orders` | `portfolio` | shell branch 3 | `PortfolioScreen(tab:)` | dev-trading |
| `/more` | `more` | shell branch 4 | `MoreScreen` | dev-perf |
| `/stock/:id` | `stockDetail` | root (covers shell) | `StockDetailScreen(instrumentId:)` | dev-trading |
| `/alerts` | `alerts` | root | `AlertsScreen` | dev-trading |
| `/strategy` | `strategy` | root | `StrategyBuilderScreen` (reads the draft controller) | dev-ai |
| `/risk-notice` | `riskNotice` | root, `push<bool>` result | `RiskNoticeScreen` | dev-trading |
| `/more/socket-lab`, `/more/clock` | `socketLab`, `debugClock` | root | developer screens | dev-perf |

Bottom sheets (order ticket, alert create, greeks) and dialogs stay `showSpSheet` / `showDialog` on the root navigator:
they are non-opaque, keep the page under them live (HLD §8.2), and are never deep-link targets.

**Shell:** `StatefulShellRoute.indexedStack` with five `StatefulShellBranch`es, `preload: false` (go_router's default):
a branch's navigator is built on first visit and kept after, which is TR-13 (lazy tabs, scroll kept) with no code of
ours. Inactive branches sit under `Offstage` + `TickerMode(false)`, the ADR-0004 backup. `AppShellScaffold(navigationShell)`
draws the `NavigationBar`; a tap calls `navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex)`
(re-tap returns the tab to its root). Our `AppShell` widget and the `visited` set are deleted.

**Typed route helpers** (hand-written; one file per feature, `features/<f>/presentation/<f>_routes.dart`):
```dart
abstract final class MarketRoutes {
  static String stock(String instrumentId) => '/stock/${Uri.encodeComponent(instrumentId)}';
  static GoRoute stockRoute(GlobalKey<NavigatorState> root) => GoRoute(
    path: '/stock/:id', name: ScreenId.stockDetail.name, parentNavigatorKey: root,
    builder: (_, state) => StockDetailScreen(instrumentId: state.pathParameters['id']!));
}
Future<void> openStock(BuildContext context, String instrumentId) {          // §10.2 name kept
  final onStock = GoRouter.of(context).state.name == ScreenId.stockDetail.name;
  final location = MarketRoutes.stock(instrumentId);
  return onStock ? context.pushReplacement(location) : context.push(location); // D4 rule kept
}
```
`openChain(context, args)` = `context.go(OptionsRoutes.chain(args))`: `go` drops pushed root routes and selects branch 1, so
the `popUntil` + `select(options)` of D1 and the `chainTargetProvider` handoff are gone. `ChainArgs.toQuery()` /
`ChainArgs.fromQuery(Map<String, String>)` are pure functions in `features/options/domain/` (unit-tested, unknown or
malformed values → `null` fields). The chain screen forwards a new `target` to `ChainController.focus(args)`.
`openOrderTicket` checks the ack, then `await context.push<bool>('/risk-notice')` for F&O, then shows the sheet.
`openStrategyBuilder(context, args)` = `ref.read(strategyDraftControllerProvider.notifier).load(args)` then
`context.push('/strategy')`. Route-path strings appear only in `*_routes.dart` files (CI grep, TR-32).

`app/router/app_router.dart` composes the feature route lists into one `GoRouter`, exposed as
`final goRouterProvider = Provider<GoRouter>(...)` (disposed with the container), with `rootNavigatorKey`,
`observers: [visibilityObserver, analyticsScreenObserver]`, `initialLocation: '/watchlist'`, and `onException` that sends an
unknown location to `/watchlist` with a `linkNotFound` feedback message. `MaterialApp.router(routerConfig: router)`.

**ScreenVisibility with go_router** (ADR-0004 stays; only its inputs change):
- `screenVisibleProvider(ScreenId)` keeps its signature and formula: a tab is visible when it is the selected tab and no
  opaque route covers the shell; a routed screen when it is the top opaque route.
- **Selected tab**: `selectedTabProvider` (`Notifier<ScreenId>`, replaces `appShellControllerProvider`) has one writer,
  `AppShellScaffold`, which sets it in a post-frame callback when `navigationShell.currentIndex` changes (a provider may not
  be written during build). The router is the source of truth; the provider is its mirror. One frame of lag before a hidden
  tab releases its stream is far inside NFR-14.
- **Covered**: `VisibilityRouteObserver` is passed in `GoRouter(observers:)`, so it watches the root navigator, where every
  opaque route above the shell lives. The shell's own page (the root's first route) is ignored, as `home` was. Page-based
  pushes, pops and `go` replacements all reach `didPush` / `didPop` / `didRemove` / `didReplace`.
- Routes inside a branch (none in v2.0) would need the observer on that `StatefulShellBranch(observers:)`; adding one needs
  an architect note.

## Consequences
- Deep links and notification taps become `router.go(uri.path)` (ADR-0016). Back, Android predictive back and iOS swipe
  work per branch.
- Removed: `core/navigation/root_navigator.dart` (key moves to `app/router/`), `openers.dart` (helpers move to feature
  `*_routes.dart`), `chain_target.dart`, `core/lifecycle/app_shell.dart`, `AppShellController.select`. D1 and D4 mechanics
  are replaced; their rules (one owner of tab state, never two stacked stock pages) hold.
- New dependency `go_router` (TRD §1.1). Tests pump `MaterialApp.router` with a test `GoRouter`; a `test/helpers/sp_app.dart`
  helper builds it with overrides.
- S-13 (AppShell, in progress) stops and is replaced by refactor story R-4.
