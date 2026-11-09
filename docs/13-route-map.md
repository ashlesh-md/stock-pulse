# Stock Pulse route map

Typed paths and query parsing live with each `AppRoute` type in `stock_pulse/lib/app/router/app_route.dart` and its `detail_routes.dart` / `shell_routes.dart` parts. `app_router.dart` is the only route-to-screen map. When adding a screen, add its typed route, map it in the router, and update this table.

| Route | Path | Screen | Placement |
|---|---|---|---|
| `WatchlistRoute` | `/watchlist` | `WatchlistTwoPane` | Shell tab |
| `OptionChainRoute` | `/options?u=&e=` | `ChainScreen` | Shell tab |
| `AiChatRoute` | `/ai` | `AiChatScreen` | Shell tab |
| `PortfolioRoute` | `/portfolio?tab=` | `PortfolioScreen` | Shell tab |
| `MoreRoute` | `/more` | `MoreScreen` | Shell tab |
| `StockRoute` | `/stock/:id` | `StockDetailScreen` | Root route; detail pane on expanded watchlist |
| `StrategyRoute` | `/strategy` | `StrategyBuilderScreen` | Root route |
| `OrderTicketRoute` | `/order/:id` | `OrderTicketScreen` | Root route; typed query prefill |
| `AlertsRoute` | `/alerts` | `AlertsScreen` | Root route |
| `AddFundsRoute` | `/more/add-funds` | `AddFundsScreen` | Root route |
| `DebugClockRoute` | `/more/clock` | `DebugClockScreen` | Root route |
| `SocketLabRoute` | `/more/socket-lab` | `SocketLabScreen` | Root route |

External links are normalized in `deep_link.dart`; they can open read-only routes, while order tickets remain in-app. Route parsing, equality, and typed order-prefill coverage is in `test/app/router/app_route_test.dart`; actual screen mapping is exercised by `test/app/router/app_router_test.dart`.
