# 10 · Change request CR-2 (from the user, 7 Nov 2026, during the W1R refactor)

Decided by the engineering manager to save time; these override any older doc where they disagree. The user also asked to finish fast and use fewer tokens, so there are no more doc rounds: developers apply these directly and update their LLD in a few lines.

## Structure rules (apply in the current refactor stories)

| # | Rule | Decision |
|---|---|---|
| 1 | DI separate from controllers | No provider in a controller file. Each feature has `features/<f>/di/`: `<f>_data_providers.dart` (repositories, APIs; owner dev-realtime) and `<f>_providers.dart` (controller providers; owner of the controller). Core modules the same: `core/<m>/di/`. |
| 2, 4 | Routes not in presentation; sealed screens | Routes live in `lib/app/router/` (owner dev-perf). `sealed class AppRoute` with one subclass per screen (`WatchlistRoute`, `StockRoute(instrumentId)`, `OptionChainRoute(underlying, expiry?)`, `OrderTicketRoute(args)`, `AddFundsRoute`, `AiChatRoute`, `StrategyRoute(args?)`, ...): each has `path`, `name`, typed args, `location` and `fromState(GoRouterState)`. Screens never build paths; they call `context.goTo(route)` / `pushTo(route)` from `lib/app/router/navigation.dart`. Deep links parse through `AppRoute.fromUri`. The `*_routes.dart` files in features are removed. |
| 3, 5 | Presentation split, one widget per file | `presentation/screens/` (one screen per file) and `presentation/widgets/` (one public widget class per file; no private widget classes hidden at the bottom of a screen file). Small private helpers are fine only if they are functions, not widget classes. |
| 6 | Scalable, extensible, testable | Interfaces at boundaries, constructor injection, no statics with state, no singletons outside DI. |
| 18 | No raw API strings | `features/<f>/data/<f>_api.dart` holds typed endpoints (`Endpoint` value: method, path builder, query builder) built on one `core/network/domain/endpoint.dart`; `ApiClient` takes an `Endpoint`, never a string. Socket ops the same in `core/network/domain/socket_ops.dart`. Owner dev-realtime. |

## Product fixes and features (next batch, after the refactor)

| # | Item | Owner |
|---|---|---|
| 7 | **Bug:** the Live badge stays Live when the socket is frozen. Show `Delayed` (warning colour) when no frame or keep-alive for longer than the stale threshold, and `Reconnecting` / `Offline` as now. | dev-realtime (status), dev-trading (badge) |
| 8 | Selected tab looks weak in dark and light themes: themed `NavigationBar`/`NavigationRail` indicator, icon and label colours with AA contrast. | dev-perf (shell), tokens from design system |
| 9 | **Responsive layouts** (web and macOS look bad): breakpoints compact < 600, medium 600–1024, expanded ≥ 1024. Bottom bar on compact, `NavigationRail` on medium+, max content width, two-pane layouts on expanded (watchlist + stock page, chain + ticket, chat + cards). | dev-perf (shell, breakpoints), each owner for their screens |
| 10 | **Kite-like chart gestures**: pinch zoom around the focal point, one-finger pan with fling momentum, double-tap to reset, long-press then drag crosshair, horizontal scroll with mouse wheel / trackpad, keyboard arrows on desktop. | dev-trading |
| 11 | **Portfolio rows are tappable**: a position/holding detail sheet with P&L breakdown and **Buy more** / **Exit (sell)** that open the order ticket prefilled. | dev-trading |
| 12 | **Add funds** screen under More, like Kite: amount field, quick amounts, method picker (UPI, net banking; simulated), confirm → server credits the demo account → funds update live. | dev-perf (screen), dev-realtime (server endpoint) |
| 13 | **Favourites**: pin stocks to the top of the watchlist and drag to reorder; stored on device. | dev-trading |
| 14 | **AI chat**, simulated but best UX: attachments (image or file, preview chip, size limit, remove), typing/streaming loader, message states (sending, failed with retry), paginated history (load older on scroll up, kept on device), empty state with suggested prompts. | dev-ai |
| 15 | **Order sheet redesign** (clear buy/sell header, price, quantity stepper, product/order type pickers, charges and margin summary, swipe-free confirm). | dev-trading |
| 17 | **Snackbar redesign** (icon, tone colour, action, rounded floating card, respects safe area and keyboard). | dev-trading (feedback host) |
