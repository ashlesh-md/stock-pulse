# 11 · Pending work: hand-off for any agent (7 Nov 2026)

Project root: `.`
Packages: `stock_pulse/` (Flutter app), `market_server/` (Dart server), `packages/option_math/` (pricing + payoff maths).
Nothing is committed yet (last commit `f6a9666` is v1). Do not commit or push unless the user says so; never add AI attribution.

## Update 9 Nov 2026, current checkpoint (read this first)

- **S-28b moved to review:** uncertain order submission reuses one idempotency key for the initial POST and at most two retries; it checks GET-by-clientKey after each timeout and accepts only an exact key match. The ticket changes from “Placing…” to “Checking status…” after 3 seconds. Unknown outcomes persist locally as Pending across restart without resubmission; Orders offers refresh only, disables refresh only while Offline, and replaces Pending on server order updates. **Verified:** focused controller, persistence, portfolio Pending, ticket, and TestServer dropped-ack suites pass; analyzer clean. Android launch is still blocked because DNS/network cannot fetch the configured Gradle 9.3.1 distribution.
- **S-46 moved to review:** reset now has regression evidence that it clears server state, prefs and snapshot, invalidates the risk-notice acknowledgement, and re-shows the notice. Offline reset is disabled with “Needs connection”. Warm portfolio state keeps cached holdings after failed requests, continues quote subscriptions for cached symbols, and derives totals equal to `PortfolioSummary.compute`; offline hide does not write cached-only data. Compact portfolio summary layout avoids pushing empty/error actions below the viewport, and positions display live unrealised and realised totals. **Verified:** full serial Flutter suite passes (958 tests), coverage 100.00% (9,923/9,923); analyzer `--fatal-infos`, file length, deny-list and no-dropdown checks pass. **Board: 33 done, 57 review, 20 todo, 1 in progress.** Planning/build remain in progress; QA, engineering review and Gate 3 are open.
- **S-27 no-default selection:** when neither the route nor saved preferences specify an option underlying, the screen asks the user to choose; no implicit NIFTY selection is made. The chooser and chain app-bar picker route to the chosen underlying, and the remembered choice restores on later visits. **Verified:** full serial Flutter suite passes (959 tests), coverage 100.00% (9,938/9,938); analyzer `--fatal-infos`, file length, deny-list and no-dropdown checks pass. S-27 remains in review.
- **R-5 analytics/push/deep-link progress (still in progress):** added the domain `Analytics` contract (`logEvent`, `setScreen`, consent-gated user properties, reset) and expanded the typed catalogue. Screen/deep-link analytics replace stock/order identifiers with route patterns; validation rejects sensitive keys and free-text strings. `tool/ci/analytics_catalog_check.dart` enforces catalogue-only declarations. Push messages use a typed alert/order/system kind; taps log `push_opened`; foreground messages show feedback with a validated `View` destination, and persisted seen alert IDs suppress duplicate foreground notices. Invalid links show localized feedback; unknown instrument links now return to Watchlist with that feedback after a 404. Added cold/warm `app_open` timing, one-minute `connection_changed` throttling, chart settings/open, order-sheet/confirm/result/stale-block, risk-notice and AI-card-action events. Safe `/trade/{symbol}` links open the ordinary risk-gated order ticket without submitting; malformed trade parameters are refused. Narrow stock order summary rows now constrain labels and prices to prevent overflow. Added Android verified-link and iOS associated-domain placeholders plus assetlinks/AASA templates; analytics consent defaults to debug-on/release-off. **Verified:** full serial Flutter suite passes (953 tests); coverage is 100.00% (9,838/9,838); analyzer `--fatal-infos`, file length, deny-list and quality checks pass. iOS simulator build succeeds; native plist and JSON templates parse. Android APK build remains unverified because the Gradle 9.3.1 distribution download timed out on retry. **Remaining in R-5:** finish FR-175–188 audit, add draw/full-screen chart event call sites as dependent chart stories land, exercise platform links at runtime, and complete Android build verification. **S-42 moved to review:** offline refresh is blocked without disabling scrolling; MIS/CNC rows remain separate with aggregate P&L; two-lot MIS exit prefill, pending-to-final updates, resync delivery, and 15:20 MIS square-off P&L are covered by app and server tests. Board: 33 done, 55 review, 21 todo, 1 in progress. Build, QA, engineering review and Gate 3 remain open.
- **S-44 moved to review:** order tickets now show available funds from the live account stream, suppress simulated margin for short option sells, and display animated, dismissible nudges for a limit more than 3% from LTP, an order above 25% of available funds, expiry today, and stale underlying data. Server `insufficient_funds` maps to a localized inline rejection. Consolidated all portfolio REST endpoint declarations (positions, holdings, funds and add funds) in `stock_pulse/lib/features/portfolio/data/portfolio_api.dart`. **Verified:** full Flutter suite 953 pass; coverage 100.00% (9,838/9,838); analyzer `--fatal-infos`, file length, deny-list, quality, endpoint and architecture checks pass. Board: 33 done, 55 review, 21 todo, 1 in progress.
- **S-40 resync/restart close-out:** registered market, order, positions, holdings, funds and alert reloaders against the shared coordinator; reconnect now awaits all active reloaders before `resyncCompleted`. Account streams replace list state from REST snapshots and buffer/replay socket updates received during a fetch; funds preserve higher versions when a slower REST response arrives. The real MarketServer/socket test performs 20 server re-serve cycles on one port, verifies each recovery within 10 seconds, and confirms positions match after the server resets state. **Verified:** full app suite 936 pass; coverage 100.00% (9,553/9,553); server 267 pass; option_math 40 pass; all analyzers clean; layer rules pass; file-length 0 over 300, deny-list 0, no-dropdown 0. S-40 moved to review. Board at that checkpoint: 33 done, 53 review, 24 todo. QA, engineering review and Gate 3 remain open.
- **S-39 MarketReads and AI server close-out:** AI market analytics now use all option strikes for PCR, max call/put OI and max-pain payout, even when the caller requests a narrow row window. Lot size comes from each underlying's option configuration. `LiveMarketReads` hides mutable dependencies and returns defensive list/candle snapshots. A fixed OI fixture proves max pain can differ from ATM, verifies full-chain aggregation and RELIANCE lot size; a real `MarketServer` test streams NIFTY AI `start`→`done` while `/debug/subscriptions` reports `activeAiAnswers` 1→0. **Verified:** server suite 267 pass; analyzer clean. S-39 moved to review. Board: 33 done, 52 review, 25 todo. QA, engineering review and Gate 3 remain open.
- **S-38 alerts close-out:** a subscribed price crossing now has direct server protocol coverage for one alert frame containing its `alertId`, `triggeredAt` and triggered status; a closed-market step emits no trigger. A client repository test sends the same trigger live and again in the resync REST snapshot and confirms a single emission. Existing queue coverage confirms IDs enter persisted `seenAlertIds`. **Verified:** server suite 265 tests and analyzer clean; app alert tests and analyzer clean. S-38 moved to review. Board: 33 done, 51 review, 26 todo. QA, engineering review and Gate 3 remain open.
- **S-37 T+1 settlement close-out:** CNC market fills now debit funds immediately but remain unsettled and cannot be sold until the next trading-day roll. The scheduled 09:00 day-roll moves those fills to settled holdings once; settled sells reduce holdings and credit proceeds. `/api/v1/holdings` now returns settled shares, while transferred shares leave `/api/v1/positions`. Added broker and REST acceptance coverage for unsettled-sale rejection, idempotent delivery, fund debits/credits, and the actual MarketClock day-roll. **Verified:** server suite 263 tests and analyzer clean; client portfolio repository/stream suites 9 tests pass. S-37 moved to review. Board: 33 done, 50 review, 27 todo. QA, engineering review and Gate 3 remain open.
- **S-36 lifecycle close-out:** the iPhone 17 Pro Max integration now proves the fast tab flip sends no quote-unsubscribe frame; pushing a stock page releases the watchlist IDs and keeps RELIANCE, then restores the list on pop. Hiding closes the socket and reaches zero server sessions within 2 seconds, stays disconnected for 10 seconds, and resuming restores one session with the original quote IDs. Fixed the integration harness hang by waiting on wall time instead of pumping multiple seconds of frames after hide. **Verified:** lifecycle integration passes on simulator; watchlist visibility and lifecycle unit tests pass; the paused-socket test observes no reconnect for 10 seconds; server suite (263) and analyzer clean. S-36 moved to review. Board: 33 done, 49 review, 28 todo. QA, engineering review and Gate 3 remain open.
- **S-34 close-out:** strategy payoff charts now have single-leg and straddle goldens in both themes. Fixed crosshair tooltip placement so it follows the pointer and clamps within the chart; tests assert in-bounds movement and one haptic only when crossing breakeven. Added strategy-route visibility assertions. Existing live-feed coverage proves stale/IV-less today line suppression, and draft tests cover the four-leg cap and feedback. **Verified:** strategy/router suites pass (61 tests); full app suite 929 tests pass; coverage 100.00% (9,537/9,537); analyzer clean; file-length 0 over 300; deny-list 0; no-dropdown 0. S-34 moved to review. Board: 33 done, 48 review, 29 todo, 0 in progress. QA, engineering review and Gate 3 remain open.
- **Latest continuation:** S-33 is now in review. Added geometry-based proof for a tall card at 60% visibility, release below 60% after the 200 ms debounce, hidden-tab release, AI trade action arguments with no order placement, and the 5.0/5.1-second freshness boundary. The market-depth title now lives in the same padded component as the bid/ask table, and the stock detail test asserts their left edges match. **Verified:** app suite 924 tests pass; app coverage 100.00% (9,529/9,529); app analyzer clean; file-length 0 over 300; deny-list 0; no-dropdown 0. One parallel no-dropdown invocation hit a transient native-asset codesign race, then passed when rerun alone. Board: 33 done, 47 review, 30 todo, 0 in progress. QA, engineering review and Gate 3 remain open.
- **Latest continuation:** S-29 moved to review after implementing the strike long-press Greeks sheet (using the injected clock, chain spot and IV; missing IV has an explicit empty state), chain-cell Add to strategy feedback, and non-destructive cross-chain Start new. Chain Buy still opens the matching contract/side with NRML and the ticket's documented one-lot default. The chat stale badge now follows the quote's server confirmation time and stays visible alongside refresh errors, instead of using the AI answer arrival time or disappearing on stream errors. The stock chart toolbar stacks and wraps controls on phone widths; market-depth Orders/Qty headings align with their fixed-width value columns; moving ATM updates the Back-to-ATM visibility. The order confirm hint now prioritizes field validation issues over market preflight reasons. **Verified:** full app suite 921 tests pass; coverage 100.00% (9,528/9,528); analyzer clean; file-length 0 over 300; deny-list 0; no-dropdown 0. Board: 33 done, 46 review, 31 todo, 0 in progress. QA, engineering review and Gate 3 remain open; do not treat the board as complete.

- **Verified in the current worktree:** all three analyzers clean; app **902 tests pass**, server **260 tests pass**, option_math **40 tests pass**; app coverage is **100.00% (9,282/9,282 executable lines)**. No Dart file exceeds 300 lines; deny-list and no-dropdown checks report 0 findings.
- **Socket work completed in this pass:** S-8 debug hooks and S-10a MarketSocket resync now have acceptance tests; quote subscriptions retain their 300 ms handoff; resync sends once per gap and runs registered reloaders. S-8 and S-10a moved to review.
- **UI fixes in this pass:** chat quote cards use the latest server-confirmed quote time for freshness; chat composer hides the character counter; option-expiry loading retains the existing chain without a flashing progress line; portfolio sections animate and preserve scroll position. Contract-sheet BUY/SELL actions are compact, responsive and retain 48px tap height; the equity row-action sheet no longer overflows its height cap. Chart range readout now has a fixed two-line height, the stock header avoids narrow-screen overflow, all app sheets use the shared sheet helper and compact root columns, selected navigation labels contrast with the surface, and chat hides the bottom bar while keeping the floating tab shortcut. B16–B19 moved to review with regression coverage.
- **Latest screenshot fixes:** B20 is implemented and awaiting review. Removed the flashing strategy refresh line and top-aligned the order ticket and option-risk gate content to eliminate the large vertical gap. Strategy, order-ticket, and watchlist focused suites pass (20 tests); `flutter analyze --fatal-infos` is clean. S-17 now has coverage for targeted rebuilds across 50 rows, per-instrument stale coloring, and index long-press actions, and is in review.
- **Picker close-out:** S-59 now has dark/light sheet goldens at 1× and 2× in addition to the existing behavior and accessibility checks. The combined picker suites pass (12 tests), and the app analyzer is clean; S-59 is in review.
- **Stock page and order/chart screenshot follow-up:** fixed the stock detail data branch so `(hasData, error, instrumentKind)` is matched consistently; the previous tuple mismatch left loaded stock details blank. Added the market-status pill and index-specific behavior: no market-depth section or BUY/SELL bar for indices, while Options navigation remains available. Stock detail/sheet/chart flag suites pass (16 tests). The order-risk gate starts directly below the ticket app bar, verified by its geometry test; the order ticket and payoff chart suites pass (11 tests). The dotted 1D chart reference in the supplied crop is the previous-close baseline. S-18 moved to review.
- **Layer and regression cleanup:** replaced presentation imports of `market_data_providers.dart` with the market application's latest-quote provider facade. Fixed test containers that omitted analytics overrides. The complete app suite passes (890 tests); the architecture test passes, and analyzer, file-length, deny-list, and no-dropdown checks are clean. Coverage now identifies 12 remaining executable lines across quote freshness and row-action paths; those are still open. Split oversized stock-detail, watchlist, and portfolio tests into smaller suites without removing their cases.
- **S-60 adoption and analytics:** the no-dropdown gate reports zero choice dropdowns. Added `watchlist_row_action` and centralized `error_shown` analytics events with coverage; picker adoption is covered across chart, study, order, chain, and alert UI. Focused feedback/watchlist and chain/alert/study suites pass (52 tests total), and the analyzer is clean. S-60 is in review.
- **S-43 alert path:** banner queuing already waited for open sheets and deduped alert IDs; added an accessible triggered-alert badge in More and `alert_opened` analytics when View routes to a stock. Focused alert queue, banner, and More suites pass (11 tests); S-43 moved to review.
- **S-68 formatting and strings:** added locale-keyed `AppFormatter` for numbers, prices, dates, and times while preserving `Fmt` call sites; expanded Indian grouping and locale resolution coverage for all string areas and bundled image paths. Formatter/l10n suites pass (14 tests), analyzer clean; S-68 moved to review.
- **Shortcut UX:** the compact tab shortcut is a small movable anchor with an animated radial tab menu; the menu closes on outside tap. Responsive-shell tests pass.
- **Server checks in this pass:** full 260-test suite and analyzer pass. Added S-23 pre-open option-price freeze coverage and S-49 load-mode coverage proving a tick emits all equity and generated option IDs. S-25 acceptance coverage found and fixed queued pre-open limit orders being skipped by the broker tick matcher. S-23, S-25, S-26 and S-49 are in review.
- **Current board:** 33 done, 43 review, 34 todo, 0 in progress. S-5, S-6, S-7 and S-16 were closed after checking their acceptance tests; B9–B11, B14–B20 and the noted story work moved to review. Build is still in progress; QA, engineering review, and Gate 3 remain open. Do not treat the board as complete.
- **Continuation checkpoint:** the compact shortcut is now shown only on chat; selecting a radial destination restores the bottom bar. The radial buttons animate out from and back toward the anchor, and outside tap closes the menu. The responsive shell suite passes (9 tests); app analyzer, file-length (0 over 300), and deny-list (0 hits) pass. S-41 now retains the newest 500 of 600 Socket Lab frames and groups Demo clock and Socket Lab under More › Developer; its focused More/Socket Lab suites pass (12 tests). The stock header price is left-aligned with Last trade; its focused acceptance suite passes (3 tests). The option expiry switch keeps the old chain visible and no longer overlays a flashing line; expiry screen tests pass (10). Contract BUY/SELL actions are compact and tap-sized; the focused sheet test passes. S-31 seeds terminal outcomes from GET /orders, queues updates while seeding, dedupes repeat updates, and gates success/rejection haptics on preferences; 8 focused listener tests pass. Latest full app run: 902 tests pass, coverage 100.00% (9,282/9,282), analyzer clean, no files over 300 lines, deny-list and no-dropdown checks clean. Board counts are 33 done, 43 review, 34 todo, 0 in progress.
- Continue with the remaining actionable tasks in this file and `docs/team/events.jsonl`; verify each acceptance criterion before changing status. Keep running the relevant checks and update this checkpoint after each meaningful batch.
- Restart the server after server changes: `cd market_server && dart run bin/server.dart --port 8080`.

The notes below this checkpoint are the original plan and earlier status reports; newer evidence and board events supersede them.

## Update 8 Nov 2026 (earlier)

- **Latest verification (8 Nov 2026):** app **766 tests pass** serially; server **238 tests pass**; option_math **40 tests pass**. All three analyzers are clean. App coverage is **96.65% (8,642/8,942 executable lines)** against the 100% gate; 300 executable lines remain uncovered, and 36 imported files contain no executable lines. File-length check reports 0 files over 300 lines; deny-list reports 0 hits.
- **The "retry" bug in chat and portfolio** came from a stale v1 server on port 8080. It now runs the current code. Always restart the server after server changes.
- **In flight now (FIX-1):** `docs/team/fix-1-brief.md` explains the batch. Bugs B3-B8 are implemented and awaiting review. The compact tab bar now animates into circular tab shortcuts; the chat composer stays at the bottom, quote stale status persists while scrolling, chat cards render rich text, and option expiry changes retain current content while loading.
  - Inputs: the code-review-1 findings (53, including 1 Critical lot-size bug), user bugs B3-B8 (`docs/team/bugs.md`), and the CR-2 items.
  - S-24, S-52, S-54, S-70 and S-74 moved to review with test evidence. S-74 still needs device-level permission-prompt verification.
  - The 100% app coverage requirement is still open; each owner must continue raising coverage in their files.
  - Continue work in owned areas. Keep FIX-1 in progress until its coverage and review requirements are met.
- **Then:** the remaining board tasks in W1-W4 below, QA, reviews and Gate 3. Current dashboard count is 47 todo, 31 review and 6 in progress; keep statuses evidence-based.

## Read before writing any code

1. `docs/team/build-brief.md`: the coding rules (layers, DI, Success/Failure, package imports, 300-line limit, human-like code, TDD, 100% coverage, lints).
2. `docs/10-change-request-2.md`: the latest structure rules (`di/` folders, sealed `AppRoute` in `lib/app/router/`, `screens/` + `widgets/`, one widget per file, typed API endpoints) and the CR-2 product items.
3. Your story in `docs/07-stories.md` (S-1…S-51) or `docs/07-stories/cr1.md` (S-52…S-76), your LLD in `docs/06-lld/<area>.md` (v2.0), HLD `docs/05-hld.md` §4 and §10.2, ADRs in `docs/adr/`.
4. File ownership per wave: `docs/08-build-plan.md` and `docs/07-stories.md` (waves). Two agents must never edit the same file at the same time.

## State right now

- **Done:** wave 0 (S-1…S-4), refactor wave R-0, R-1a, R-1b, R-2, R-3, R-4, W1R-exit.
- **Checks at the last checkpoint:**
  - analyze `--fatal-infos` is clean in all three packages;
  - tests pass: option_math 40, server 217, app 467;
  - no file is over 300 lines.
- **W1R closed (verified):**
  - all gates are green and now blocking;
  - tests pass: app 485, server 217, option_math 40;
  - coverage is 100% (app 4065/4065 lines);
  - deny-list 0, layer violations 0, no file over 300 lines.
- **Remaining board work:** tasks still marked `todo` in `docs/team/events.jsonl` have not been signed off. Do not infer completion from code presence alone; verify acceptance criteria and tests before changing their status.
- When you add a `lib/` file, regenerate the coverage import test: `dart run tool/ci/coverage_check.dart coverage/lcov.info --write-import-test`.
- **Waiting for review** (built before CR-1/CR-2; reshaped by the R stories; close them after a quick check): S-5, S-6, S-7, S-11, S-12, S-15, S-16, S-19, S-20, S-21.

## Next batch: CR-2 product items (user's priority)

| # | Item | Owner |
|---|---|---|
| 7 | **Bug:** the Live badge stays Live when the socket is frozen. Show `Delayed` when no frame or keep-alive arrives within the stale threshold. | dev-realtime (status) + dev-trading (badge) |
| 8 | Selected tab styling in dark and light themes (indicator, icon, label colours, AA contrast) | dev-perf |
| 9 | Responsive layouts for web and macOS: rail at ≥ 600, two panes at ≥ 1024, max content width | dev-perf (shell) + each owner (screens) |
| 10 | Kite-like chart gestures: focal pinch zoom, pan with fling, double-tap reset, long-press crosshair drag, mouse wheel and trackpad, arrow keys | dev-trading |
| 11 | Portfolio rows tappable → detail sheet with **Buy more** / **Exit** opening a prefilled order ticket | dev-trading |
| 12 | **Add funds** screen under More (amount, quick chips, simulated UPI/net banking; the server credits the demo account and funds update live) | dev-perf (screen) + dev-realtime (endpoint) |
| 13 | Favourites: pin to top and drag to reorder, stored on device | dev-trading |
| 14 | AI chat (simulated) with attachments, a typing/streaming loader, sending/failed/retry states, paginated history kept on device, suggested prompts | dev-ai |
| 15 | Order sheet redesign | dev-trading |
| 17 | Snackbar redesign (icon, tone, action, floating card, safe area and keyboard) | dev-trading |

## Remaining stories by wave (85 tasks on the board, 10 done)

**W1 (foundation):**
- dev-realtime: S-8 debug hooks, S-9 client time and freshness, S-10a socket v2 and resync, S-10b MarketRepository.
- dev-trading: S-17 watchlist, S-18 stock page, S-59 SpPicker.
- dev-ai: S-22 postLines and card models, S-52 indicator maths.
- dev-perf: S-61 app icon and splash from `stock_pulse/assets/brand/*.svg`.

**W2 (F&O core, AI client):**
- dev-realtime: S-23 options and pricer, S-24 chain channel, S-25 broker v2, S-26 expiry and square-off, S-49 load flag.
- dev-trading: S-27 option chain screen, S-28a/S-28b order ticket and retries, S-29 chain cell actions, S-30 risk notice, S-31 order outcome listener, S-53 chart module, S-68 formatters.
- dev-ai: S-32 chat, S-33 live cards, S-34 strategy builder and payoff.
- dev-perf: S-35 More shell, S-36 lifecycle tests, S-48a perf harness, S-67 CI checks, R-5 analytics, push placeholders and deep links.

**W3 (portfolio, alerts, AI on live data, chart tools):**
- dev-realtime: S-37 holdings and funds, S-38 alerts engine, S-39 MarketReads, S-40 resync and restart, S-56 chart store.
- dev-trading: S-42 portfolio screen, S-43 alerts UI, S-44 SL orders and funds, S-55 drawing tools, S-57 landscape chart, S-60 picker close-out.
- dev-ai: S-45 AI end to end, S-54 studies UI, S-66 AI failure cases, S-70 Bollinger and MACD, S-71 Fibonacci.
- dev-perf: S-41 debug clock and Socket Lab, S-46 reset and warm start, S-65 failure cases, S-74 notification permission, S-75 analytics toggle.

**W4 (device perf, accessibility, polish):**
- dev-perf: S-47 startup runs, S-48 frame and latency runs, S-62 dark splash, S-76 chart perf.
- dev-trading: S-50 accessibility, S-58 buy/sell from chart, S-64 failure cases, S-69 pseudo-locale, S-72 chart settings, S-73 alert at chart price.
- dev-ai: S-51 AI accessibility and chat perf.
- dev-realtime: S-63 network and socket failure cases.

Many CR-2 items overlap these stories (11 with S-42, 14 with S-32, 15 with S-28a, 12 with S-37/S-44). Build them together, not twice.

## After the build

- QA: test plan and QA report, then the QA sign-off.
- Review: `flutter-architecture-review` and `flutter-code-review`, then the engineering sign-off.
- Gate 3: product, design, QA and engineering sign-offs, then the user's release approval.
- PM questions still open for the user:
  1. Should any chart Should item be promoted to Must?
  2. Should the 100% coverage rule also apply to the server and option_math?
  3. Is there a real deep-link domain, and is Hindi the first extra language?

## How to report (so the dashboard at http://localhost:8095 stays right)

Every Bash call: `export TEAM_DIR=docs/team; T=tools/agent-team/scripts/team.py`

| What | Command |
|---|---|
| Start a story | `python3 $T task S-17 in_progress --owner dev-trading` |
| Finish a story | `python3 $T task S-17 review --owner dev-trading --note "<tests, files>"` |
| Message the team | `python3 $T say --from dev-trading --thread build "message"` |
| Your status | `python3 $T agent dev-trading working --activity "S-17: tests"` |

Never edit `events.jsonl` by hand. Restart the dashboard if it is down: `python3 $T serve --port 8095`.

## Verify before calling anything done (from each package folder)

- `stock_pulse`:
  - `flutter analyze --fatal-infos`
  - `flutter test --coverage`
  - `dart run tool/ci/coverage_check.dart coverage/lcov.info`
  - `dart run tool/ci/file_length_check.dart`
  - `bash tool/ci/deny_list.sh`
- `market_server` and `packages/option_math`: `dart analyze --fatal-infos` and `dart test`.
