# 00 · Intake: StockPulse v2

Owner: engineering manager · Status: done · Next: Discovery (business analyst)

## 1. Goal

Grow StockPulse from a practice app into a **mobile-first trading app** that covers every item of a Flutter developer job description for an AI-native retail trading platform (equity and F&O traders in India). The traders live on their phones: they check positions between meetings, place orders from a cab, and watch an option chain tick at 9:15. A lagging price or a frozen order screen there is a missed trade, so the app has to stay fast, accurate and steady at market open.

## 2. Job description → what the app must show

| # | JD item | What it means for StockPulse v2 |
|---|---|---|
| J1 | Core trading screens built for speed and one-handed use | Watchlist, stock page, **option chain**, order entry, positions, **holdings**, **P&L**; key actions reachable by thumb |
| J2 | Real-time data layer | WebSocket streams for prices, **order updates** and **alerts**; reconnection, subscription management, patchy networks |
| J3 | AI on mobile | **Chat screen** where traders ask questions and answers arrive as **live cards, charts and widgets** |
| J4 | Charts and visualisation | Fast readable charts and **option payoff diagrams** that work on small screens |
| J5 | App performance | Smooth long lists, **near-instant startup**, sensible memory and battery, no dropped frames in market hours |
| J6 | Release and quality | Clean builds, crash monitoring hooks, QA on every release |
| J7 | State management at scale | Riverpod, with the reasons written down |
| J8 | Rendering knowledge, profile before guessing | Measured startup and frame numbers in the docs |
| J9 | Platform channels | At least one native feature through a channel (e.g. haptics or a native secure store) |
| J10 | Design sense | A design system and screens that feel good on a real device |

## 3. What StockPulse already has (v1, commit f6a9666)

| Area | Status | Where |
|---|---|---|
| Dart market server: 12 NSE stocks, REST + WebSocket, conflation, idempotent orders, chaos endpoints | ✅ | `market_server/` |
| Socket client: ref-counted subscriptions, heartbeat, backoff with jitter, sequence gaps → resync, pause/resume | ✅ | `stock_pulse/lib/core/network/market_socket.dart` |
| Watchlist with per-row rebuilds and static up/down colour | ✅ | `features/market/presentation/watchlist/` |
| Stock page: 1D–5Y ranges, 6 intervals, 5 chart types, depth, stats | ✅ | `features/market/presentation/stock_detail/` |
| Order sheet: market/limit, errors over the sheet, fill notices | ✅ | `widgets/order_sheet.dart`, `order_update_listener.dart` |
| Positions with live P&L | ✅ | `features/portfolio/` |
| Socket Lab (raw frames, drop/freeze/skip-seq) | ✅ | `features/socket_lab/` |
| 77 tests (26 server, 51 app) | ✅ | `*/test/` |

## 4. Gaps for v2

| Gap | JD item |
|---|---|
| Option chain (strikes, CE/PE, OI, IV, greeks, live ticking) and F&O orders | J1, J2 |
| Holdings (delivery stocks, average price, day and total P&L) and a P&L summary | J1 |
| Price alerts streamed over the socket | J2 |
| AI chat with streamed answer cards (quote, chart, payoff, screener table) | J3 |
| Option strategy payoff diagram | J4 |
| Cache-first instant startup with stale-price safety; lazy tabs | J5 |
| Startup and frame measurements in the docs | J5, J8 |
| A platform channel (haptics on order fill) | J9 |
| One-handed layout pass and a design system review | J1, J10 |

## 5. Decisions from the user (5 Nov 2026)

- The team runs as **Claude Code subagents**, logged to `docs/team/` and shown on the dashboard (`http://localhost:8095`).
- **Grow StockPulse** in place; keep the server and socket layer.
- The **AI chat is simulated** on the market server: it reads the question and streams cards built from its own data. No API key needed.
- The pipeline **stops for the user at three gates**: scope (after PRD and design), plan (after LLD and stories), release (final sign-offs).

## 6. Constraints carried over

- Manual Riverpod 3 providers and hand-written immutable classes and JSON. **No code generation.**
- One controller per screen, production-lean; no over-engineering.
- Every feature has tests; `flutter analyze` clean; `flutter-architecture-review` and `flutter-code-review` before release.
- The app name stays **StockPulse**. Do not name it after any real company.
- Nothing is committed or pushed without the user's yes; no AI attribution in commits.
