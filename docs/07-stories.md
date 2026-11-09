# 07 · Stories and build waves: StockPulse v2

Status: **v2.1** (CR-1 re-plan + architect answers) · Author: scrum-master · Sources: `02-prd.md` v1.4, `04-trd.md`, `05-hld.md` v2.0, ADR-0009…0021,
`06-lld/README.md` (D1–D13 final; §6 defines R-0…R-5), `06-lld/{realtime,trading,ai,perf}.md`, `08-build-plan.md`, thread `planning`.
New CR-1 stories S-52…S-76 live in **[`07-stories/cr1.md`](07-stories/cr1.md)** (this file would pass 450 lines otherwise).

## 0a. Change log v2.0 (CR-1, 2026-11-07)

| # | Change | Source |
|---|---|---|
| V1 | **W1R refactor wave** R-0 → R-1a → R-1b ∥ R-2 ∥ R-3 ∥ R-4 inserted before wave 1 resumes; R-5 (analytics, push, deep links) in W2. Defined in `06-lld/README.md` §6, not repeated | architect |
| V2 | **S-13 dropped** (go_router replaces `AppShell`; observer work moves into R-4). **S-14 dropped** (folded into R-0). Their FRs/NFRs re-traced to R-4 / R-0 in §5 | architect |
| V3 | Stories in `review` (S-5, S-6, S-7, S-11, S-12, S-15, S-16, S-19, S-20, S-21) are closed on v1.1 rules; R stories reshape their code | architect |
| V4 | **25 new stories** S-52…S-76 (cr1.md): chart E12 (S-52…S-58, S-70…S-73, S-76), `SpPicker` E13 (S-59, S-60), strings/assets (S-67, S-68, S-69), icon + splash E14 (S-61, S-62), push/analytics Shoulds E15 (S-74, S-75), failure cases E16 (S-63…S-66) | PRD v1.4, UX v2.0, 03b v2.0 |
| V5 | New feature folder **`features/chart/`** split by file (dev-trading / dev-ai / dev-realtime), cr1.md §2; architect to confirm (Q2) | scrum-master |
| V6 | §2a: CR-1 notes on every remaining story (layers, `Success`/`Failure`, routes, `FeedbackController`, `AppStrings`, `SpPicker`, analytics events). Old ACs stay valid unless a note changes them | HLD v2.0 |
| V7 | §3 waves re-planned (W1R, W1 remainder, W2, W3, W4) with new stories placed and a fresh file-overlap check; §4 DoD adds CR-1 rules; §5 coverage now covers **111 Must FRs** | PRD §12 |
| V9 | **v2.1:** HLD v2.1 D14–D18. `features/chart/` confirmed, one owner per file (LLD README §6.4); maths in `chart/domain/indicators/` (D15); **S-71 → dev-ai** (`fib_levels.dart`, `fib_painter.dart` only), S-55 builds the two-anchor path + gated Fib tool, S-52 ships Fib stubs (D16); FR-157 wins, lower message waits in one slot (D17, R-2); hand-written `AppStrings` (D18, PRD v1.5). Counts: dev-trading 11, dev-ai 5. Q2–Q6 closed | architect, product-manager |
| V8 | Rules below are superseded where they name v1.1 paths: `core/providers.dart` is deleted in R-1a (not S-40); `core/navigation/**` is deleted in R-2 (openers → `<f>_routes.dart`); `core/lifecycle/**` → `core/visibility/**` in R-4; `pubspec.yaml` adds in W1R (R-0) | ADR-0010, 0011, 0015 |

## 0. Change log v1.1 (history)

| # | Change | Asked by |
|---|---|---|
| C1 | S-10 split → **S-10a** MarketSocket v2 + resync core (M) and **S-10b** MarketRepository (M). S-24, S-25, S-38, S-16 need S-10a; S-17, S-33, S-36 need S-10b | dev-realtime |
| C2 | S-28 split → **S-28a** ticket form + send-time stale block (M) and **S-28b** same-key retries, checking status, Pending (M, dep S-8). Funds row and `insufficient_funds` move to S-44 (dep S-37) | dev-trading |
| C3 | **S-48a** added (W2, dev-perf, S): non-gating perf harness skeleton; S-48 and S-51 build on it | dev-perf |
| C4 | **S-49 → wave 2**, dep S-23, last in dev-realtime's W2 queue (decision and reason in §3) | dev-realtime, dev-perf |
| C5 | S-41 owner → **dev-perf**, W3, dep S-8 + S-35 (architect approved, see C12) | dev-lead |
| C6 | Order fixes: dev-realtime W1 S-5 → S-6 → S-7 → S-9 → S-10a → S-10b → S-8; W2 S-23 → S-25 → S-24 → S-26 → S-49; S-38 after S-37, S-40 after both | dev-lead, dev-realtime |
| C7 | S-8 AC3 (`dropAckAfterStore` + `GET /orders?key=`) moved to S-25 (needs `clientKey` from Broker v2); S-7 dep S-6, AC3/AC4 added; S-5 owns `market_engine.dart` clock injection (AC4); S-40 registers reloaders and deletes the `core/providers.dart` shim | dev-realtime |
| C8 | dev-perf: S-4 deps list; S-12 AC4/AC5 + deps; S-13 AC3/AC4; S-14 size M, `tool/ci/trace_check.dart`, T25/T26; S-36 deps S-17, S-18; S-46 T24 and dep S-8 (not S-41) | dev-perf, dev-lead |
| C9 | dev-trading: deps on S-16, S-17, S-27, S-31, S-42; file lists of S-15, S-16, S-30, S-43; S-18 adds `CandleChart` flags for dev-ai | dev-trading, dev-ai |
| C10 | dev-ai: S-3 U1; S-21 dep S-1 + AC3; S-32 C5/C6/W6; S-33 W4 + `ai_action_runner.dart`; S-34 deps S-6, S-24 + W9/W11; S-39 smoke test + `activeAiAnswers`; S-51 dep S-48a | dev-ai, dev-lead |
| C11 | AI card footer fixed to "Simulated. Not advice." (PM decision, PRD v1.3); S-32 AC2 updated, open item closed | product-manager |
| C12 | Architect plan check: S-41 → dev-perf approved (dev-realtime keeps `DebugClient` and the frames stream); S-4 files add `core/lifecycle/{app_shell_controller,screen_visibility}.dart`; W1 realtime owns `core/network/**` except `api_client_lines.dart`; W3 realtime owns `features/portfolio/{domain,data}` except `portfolio_summary.dart` | architect, dev-lead |

Rules used for slicing:
- Every story ends in a testable increment (tests in the owner's LLD §Tests are the acceptance tests). Size: S ≤ 1 d, M ≤ 3 d, L ≤ 5 d.
- One owner per file (HLD §10.1, README §3, build plan §5). Stories of different owners in the same wave never touch the same file.
- Shared folders are split by file: `features/{market,options,orders,portfolio,alerts}/{domain,data}` = dev-realtime, `presentation/` = dev-trading
  (plus `orders/domain/{order_draft,order_validator,confirm_block,submit_phase,ticket_event}.dart`, `options/domain/chain_column.dart`);
  `features/more/**` = dev-perf (incl. `debug_clock/`, `socket_lab/` per C5); `core/providers.dart` = dev-realtime shim until S-40.
- `pubspec.yaml` files change only in W0 (`stock_pulse/` dev-perf; `market_server/`, `option_math/` dev-realtime); late adds at a wave checkpoint.
- Waves are integration gates, not barriers: a story may start when its deps are done and its files are free (build plan §1).
- Deferred items appear only in the Backlog section (FR-28 per D13).

## 1. Epics

| Epic | Name | FR / TR / NFR |
|---|---|---|
| E1 | Shared contracts and stubs | HLD §10.2; TR-18, TR-19, TR-22; NFR-17, NFR-18 |
| E2 | Market time, test hooks and protocol v2 | FR-6, FR-7, FR-84, FR-90…95, FR-110, FR-111, FR-116, FR-120…124; TR-1…5, TR-9, TR-11, TR-22, TR-25; NFR-7, NFR-10, NFR-11 |
| E3 | Startup, storage, lifecycle, observability | FR-80…82, FR-85…87, FR-112, FR-114, FR-125; TR-12…16, TR-23, TR-24; NFR-15, NFR-17, NFR-18 |
| E4 | Watchlist and stock page | FR-1…6, FR-10…14, FR-83, FR-90; TR-8, TR-19; NFR-12, NFR-13 |
| E5 | Option chain | FR-20…27, FR-29, FR-29a…29c; TR-7, TR-8, TR-26; NFR-5, NFR-14 |
| E6 | Order entry and safety | FR-30…39a, FR-92, FR-100, FR-101, FR-113, FR-126; TR-6, TR-10, TR-21, TR-25; NFR-8, NFR-9, NFR-10 |
| E7 | Portfolio and settlement | FR-39…49; TR-20 |
| E8 | Alerts | FR-50…55; TR-9 |
| E9 | AI chat and live cards | FR-60…67; TR-17; NFR-14 |
| E10 | Payoff and strategy builder | FR-70…73; TR-18 |
| E11 | Device performance and release polish | NFR-1…6, NFR-12, NFR-15, NFR-16 |
| CR-1, E12…E16 | Refactor, chart, UI kit, brand, links/push/analytics, failure cases (v2.0) | see `07-stories/cr1.md` §1 |

## 2. Stories

Format: `#### ID · title · owner · size · trace · depends`. Then files, then acceptance criteria (Given / When / Then).

### Wave 0: shared stubs and interfaces (E1)
#### S-1 · Realtime stubs, fakes and `pricing.dart` · dev-realtime · M · TR-18, TR-26, FR-27 (maths) · dep none
- Does: compiling stubs of every §10.2 type dev-realtime owns (incl. `watchlistIds`, `latestQuotes`, `seedFromCache`, `PortfolioRepository.current`), `FakeClock`, `FakeMarketClock`, fake `MarketSocket`, `TestServer` skeleton, `MarketClock`/`MarketReads` interfaces, `DebugClient`; full `pricing.dart`; `core/providers.dart` re-export shim.
- Files: `packages/option_math/**` (not `payoff.dart`), `market_server/pubspec.yaml`, `market_reads.dart` (interface), `core/{market_time,network}/**` (not `api_client_lines.dart`), domain/data stubs (realtime §1.3), `core/providers.dart`, `test/helpers/test_server.dart`.
- AC1: Given S=100 K=100 T=1 r=0.05 iv=0.2, when `bsPrice` runs, then CE = 10.4506 and PE = 5.5735 (±1e-4) and put-call parity holds over a grid.
- AC2: Given the stubs, when `flutter analyze` and `dart analyze` run on all three packages, then 0 issues.
#### S-2 · Theme extensions, nav args and host stubs · dev-trading · M · TR-19, D1, D4, D10 · dep none
- Does: `SpColors`/`SpTypography`/`SpThemeX`, delete `MarketColors`; `args.dart`, opener signatures; `Haptics` + `NoopHaptics`; passthrough `OrderOutcomeListener`, `AlertBannerHost`, `GlobalStaleBanner` for dev-perf to mount.
- Files: `core/theme/**`, `core/navigation/**`, `core/platform/haptics.dart`, `app/{order_outcome_listener,alert_banner_host}.dart`, `core/widgets/global_stale_banner.dart`.
- AC1: Given the app, when `grep -rn "Colors\." lib/ | grep -v core/theme` runs, then no match; `SpColors.lerp/copyWith` tests pass.
- AC2: Given `AlertArgs`, then it uses `condition: AlertCondition?` (no `AlertDirection` anywhere).
#### S-3 · AI stubs · dev-ai · S · TR-17, TR-18, D5, D11 · dep none
- Does: `payoff.dart` signatures, `StrategyDraftRepository` + `AddLegResult`, `openStrategyBuilder` stub, `mountAiApi` stub, `ApiClientLines` stub.
- Files: `packages/option_math/lib/src/payoff.dart`, `features/strategy/**`, `market_server/lib/src/ai/ai_api.dart`, `core/network/api_client_lines.dart`.
- AC1 (U1): Given a draft, when `addLeg` runs, then `added` under 4 legs, `full` at 4, and `otherChain` for another chain with the draft unchanged.
#### S-4 · Lifecycle, storage and observability interfaces · dev-perf · S · TR-12…16, TR-24 · dep none
- Does: `ScreenId`, `appShellControllerProvider` (`select`), `screenVisibleProvider`, `SnapshotStore`, `LocalPrefs(+Data)`, `CrashReporter`, `PerfMarks`, `PaintProbe`; fakes; `stock_pulse/pubspec.yaml` adds `path_provider` and dev deps `integration_test`, `flutter_driver` (TRD §1.1).
- Files: `core/lifecycle/{screen_id,app_shell_controller,screen_visibility}.dart`, `core/storage/*` + `core/observability/*` (interfaces), `test/helpers/{fake_crash_reporter,fake_snapshot_store,fake_local_prefs,build_counter}.dart`, `stock_pulse/pubspec.yaml`.
- AC1: Given S-1…S-4 merged, when `flutter test` runs, then it compiles and the pubspec deny-list grep (perf §9.2) finds nothing.

### Wave 1: M-A foundation (E2, E3) plus independent early work
#### S-5 · Server market clock, calendar, scheduler · dev-realtime · L · FR-116, FR-120, FR-24 (calendar), FR-37 (phases), TR-4 · dep S-1
- Files: `market_server/lib/src/{ist,market_clock,market_calendar,clock_scheduler,market_engine}.dart`, `bin/server.dart`.
- AC1: Given demo mode on a weekday, holiday or weekend, when the server starts, then market time is 10:00 IST, phase Open, wall time unchanged.
- AC2: Given 09:14:59.999 / 09:15 / 15:29:59.999 / 15:30, then phases match PRD §3.2; a Tuesday-holiday expiry moves to Monday.
- AC3: Given a jump over 2 days, then dayRoll/open/close replay once each in order.
- AC4: Given the engine on an injected clock, then no ticks while Closed and pre-open publishes IEP only.
#### S-6 · Instrument metadata and 50-equity universe · dev-realtime · M · FR-6, FR-7, FR-3, TR-25, NFR-9 · dep S-1
- Files: `market_server/lib/src/{instruments,models,tradable}.dart`, `features/market/domain/instrument.dart`.
- AC1: Given the server, when `GET /instruments` runs, then 50 equities + NIFTY carry `kind`, lot, tick, band; default watchlist NIFTY, RELIANCE, HDFCBANK.
- AC2: Given a fixture with lot size 50, when parsed, then `lotSize == 50` (no constant anywhere).
#### S-7 · Protocol v2 gateway · dev-realtime · L · FR-93, FR-95, FR-91 (server), FR-84 (server), TR-1, TR-2, TR-3, TR-11 (caps) · dep S-5, S-6
- Files: `market_server/lib/src/{ws_gateway,rest_api}.dart`, `market_server/lib/market_server.dart`.
- AC1: Given a session, then every data frame has `seq` +1 and `asOf`; `welcome` and `pong` carry `serverTime`.
- AC2: Given an unchanged subscribed quote over 10 s, then `asOf` confirmations are ≤ 2 s apart (`ka`).
- AC3: Given skip-seq, when the client sends `resync`, then ticks snapshot and the resync ack arrive in order.
- AC4: Given two sessions, then `order` frames reach only the session subscribed to `orders`.
#### S-8 · Debug hooks and `DebugClient` · dev-realtime · M · FR-121…124, D7 · dep S-7
- Files: `market_server/lib/src/debug_api.dart`, `core/network/debug_client.dart`.
- AC1: Given RELIANCE frozen 6 s, then it is absent from ticks and `ka` and listed in `ex`; TCS keeps ticking.
- AC2: Given a backward `POST /debug/clock`, then 409 `backward_jump_requires_reset`; `POST /debug/reset {time}` succeeds.
- AC3: Given faults with status/delay on any route, then they apply; `dropAckAfterStore` on v1 `POST /orders` stores the order and drops the ack (count = 1).
#### S-9 · Client time and freshness · dev-realtime · M · FR-91, FR-94, NFR-7, TR-5, TR-6 · dep S-1
- Files: `core/market_time/**`, `core/network/network_status.dart`.
- AC1: Given ages 4.9 / 5.0 / 5.1 s, then live / live / stale; socket down or `fromCache` → stale; pre-open/closed → closed.
- AC2: Given the device clock +30 s, then `ServerClock.now()` equals server time (lowest-RTT pong of 5).
#### S-10a · `MarketSocket` v2 and resync core · dev-realtime · M · FR-84 (socket), FR-90 (`lastFrameAt`), TR-9 (core), TR-11 · dep S-7, S-9
- Files: `core/network/{market_socket,socket_messages,subscriptions,resync_coordinator}.dart` (coordinator with registrable reloaders).
- AC1: Given two holders of RELIANCE, when one leaves and the other re-listens within 300 ms, then 0 unsubscribe ops; mode = max, throttle = min.
- AC2: Given a seq gap, then exactly one `resync` op is sent, registered reloaders run, and `completed` fires once; `lastFrameAt` updates per frame.
#### S-10b · `MarketRepository` · dev-realtime · M · FR-81 (seed), FR-91, D3, D9 · dep S-10a, S-4
- Files: `features/market/domain/quote.dart`, `features/market/data/**` (`market_repository`, `providers` with `liveQuoteProvider`).
- AC1: Given `seedFromCache`, when the first live frame arrives, then only that quote turns `fromCache == false`; `ka` emits an `==` quote with a new `asOf`; an older REST `asOf` is not applied.
- AC2: Given `setWatchlist`, then `watchlistIds` and `latestQuotes` reflect it and `markStructuralDirty` is called once.
#### S-11 · Bootstrap, crash hooks, marks · dev-perf · M · FR-125, NFR-15, TR-14, TR-23, TR-24 · dep S-4
- Files: `lib/{main,bootstrap,app}.dart`, `core/observability/**`.
- AC1: Given a pending snapshot future, when one frame pumps, then the shell and watchlist skeleton are painted (T1).
- AC2: Given a throw in build, then 1 non-fatal error is recorded; an uncaught async error → fatal (T19).
- AC3: Given `kPerfProbe == false`, then probe marks are no-ops; the 2nd `cache_painted` is ignored (T20).
#### S-12 · Snapshot and prefs storage · dev-perf · L · FR-80, FR-87, TR-15, TR-16, D3, P1 · dep S-4, S-1 (`watchlistIds`, `latestQuotes`, `seedFromCache`, `PortfolioRepository.current` stubs)
- Files: `core/storage/**`, `test/core/storage/**`.
- AC1: Given schemaVersion 0, 8 days old or truncated JSON, when read, then `null`, file deleted, one `cache_discarded` log, no throw (T5).
- AC2: Given 3 writes while one is in flight, then 2 disk writes, the file equals the 3rd; a valid main file wins over a leftover `.tmp` (T6, T7).
- AC3: Given 501 seen alert ids, then 500 remain (oldest dropped); the snapshot has no `summary` field (T9).
- AC4 (T8): Given dirty + 30 s, then 1 save; offline start + hide → 0; resync saves only while live.
- AC5: Given the 64 KB fixture, then the median of 20 decodes is ≤ 4 ms (CI bench).
#### S-13 · **(dropped in v2.0 → R-4)** `AppShell`, lazy tabs, visibility, background · dev-perf · M · FR-82, FR-86, FR-85 (client), TR-12, TR-13 · dep S-4, S-2, S-12
- Files: `core/lifecycle/**` (not `screen_id.dart`), `app.dart` mounting of S-2 host widgets.
- AC1: Given the first frame, then Options, AI, Portfolio and More are not built and their controllers do not exist (T11).
- AC2: Given an opaque `stockDetail` over the watchlist, then `screenVisibleProvider(watchlist)` is false; a sheet over it keeps `(stockDetail)` true (T13, T14).
- AC3 (T12): Given Options then Watchlist, then the watchlist scroll offset is kept and hidden Options has `TickerMode` off.
- AC4: Given lifecycle hide, then the shell calls socket `pause` and `SnapshotScheduler.onHide` once each (FR-85 wiring).
#### S-14 · **(dropped in v2.0 → R-0)** CI checks · dev-perf · M · NFR-17, NFR-18, TR-19, TR-23 · dep S-4
- Files: CI workflow, `test/architecture/import_rules_test.dart`, `tool/ci/trace_check.dart`.
- AC1 (T25): Given a PR, then analyze, tests, deny-list, `Timeline.` and `Colors.` greps and the import-rule test run.
- AC2 (T26): Given the LLD test tables, when the trace check runs, then it fails if any Must FR has no test.
#### S-15 · Haptics platform channel · dev-trading · M · FR-100, FR-101, FR-126 · dep S-2
- Files: `core/platform/{haptics,haptic_dedupe}.dart`, `android/.../{MainActivity,SpHaptics}.kt`, `AndroidManifest.xml` (VIBRATE), `ios/Runner/{AppDelegate,SpHaptics}.swift`, `test/helpers/fake_haptics.dart`.
- AC1: Given a mocked channel, when `success()` runs, then the handler receives `success`; `MissingPluginException` → no throw, 1 log.
#### S-16 · Core widgets and real openers · dev-trading · M · FR-2, FR-14, FR-83, FR-90 (banner), D1, D4 · dep S-2, S-9, S-10a, S-13
- Files: `core/widgets/**`, `core/navigation/{openers,sheet_presence,chain_target,instrument_id}.dart`.
- AC1: Given `openStock` with `stockDetail` on top, then `pushReplacement`; every pushed route has `RouteSettings(name: ScreenId.x.name)`; `openChain` pops to the shell then `select(options)`.
- AC2: Given no frame for 5.1 s while Open, then the global stale banner shows; the badge shows Live / Reconnecting / Offline; up/down is never colour-only.
#### S-17 · Watchlist on the new `Quote` · dev-trading · M · FR-1, FR-3, FR-4 (S), FR-5, FR-81 (rows), TR-8 · dep S-16, S-10b, S-12
- Files: `features/market/presentation/watchlist/**`.
- AC1: Given 50 rows, when A ticks, then A is built once and others 0 (build counter); cached rows stay grey until their first live frame.
- AC2: Given RELIANCE frozen 5.1 s (FakeClock), then only that row is stale; long-press NIFTY shows 3 actions (no Buy/Sell).
#### S-18 · Stock page · dev-trading · M · FR-10…13, FR-6 (UI), NFR-13 · dep S-16
- Files: `features/market/presentation/stock_detail/**` (incl. `candle_chart.dart`).
- AC1: Given NIFTY, then no Buy/Sell and no depth; RELIANCE at 360×800 → Buy/Sell in the bottom 25 %, ≥ 48 dp, enabled when stale.
- AC2: Given clock 09:10, then the chip reads "Pre-open"; `CandleChart(interactive: false, showVolume: false)` renders for dev-ai and defaults keep today's chart.

#### S-19 · `payoff.dart` · dev-ai · M · FR-72, FR-71 / FR-70 (maths), TR-18 · dep S-1, S-3
- Files: `packages/option_math/lib/src/payoff.dart`, `packages/option_math/test/payoff_test.dart`.
- AC1: Given a long CE, then maxLoss = −premium × units, maxProfit null, BE = K + premium; iron condor BEs exact, no duplicate at a kink (P1–P4).
- AC2: Given years ≤ 0, then `valueToday == payoffAtExpiry`; 0 or 5 legs → `ArgumentError` (P5, P6).
#### S-20 · AI intent parser, glossary, templates · dev-ai · M · FR-61, FR-65 · dep S-1
- Files: `market_server/lib/src/ai/{ask_request,intent,intent_parser,glossary,strategy_templates}.dart`.
- AC1 (S1): Given ≥ 2 positives per rule R1–R7, then each maps to its intent; "hdfc bank" wins the longest match; "buy reliance" → quote + tradeWords.
#### S-21 · Answer builder, NDJSON stream, `ai_api` · dev-ai · L · FR-60, FR-62, FR-67 (server), TR-17 · dep S-20, S-1
- Files: `market_server/lib/src/ai/{answer_builder,card_json,answer_stream,ndjson,ai_api}.dart`. E2E tests use a test router (`requireAuth` + `mountAiApi(debug: true)` + `FakeMarketReads` + gated `FakeMarketClock`) on `shelf_io`, ephemeral port.
- AC1 (S2, S3): Given a fake `MarketReads`, then ≤ 4 cards, ≤ 8 KB, `fallbackText` and `v` on every card, no price key or order action.
- AC2 (S4, S5): Given held delays, then `start` and card 1 reach the client before `done`; abort after card 1 → `active == 0`.
- AC3 (S6, S7): Given `X-Debug-Fault: error_after_card=2`, then start, 2 cards, error (ignored without debug); bad body 400, no token 401, gibberish → fallback with chips.
#### S-22 · `postLines`, `AiRepository`, card models · dev-ai · M · FR-67 (client), FR-60 · dep S-3, S-1 (`ApiClient.send`)
- Files: `core/network/api_client_lines.dart`, `features/ai_chat/{data,domain}/**`.
- AC1 (C1, C2): Given chunks splitting JSON, CRLF and ₹, then lines decode; 500 → `ServerFailure`, 15 s idle → `NetworkFailure`.
- AC2 (C3): Given an unknown card type or `v = 2`, then `UnknownCard`.

### Wave 2: M-B F&O core, AI client screens
#### S-23 · Option universe and pricer · dev-realtime · M · FR-20 (server), FR-29c (listing), TR-26 · dep S-5, S-6
- Files: `market_server/lib/src/{option_instruments,option_pricer}.dart`, pricer hook in `market_engine.dart`.
- AC1: Given NIFTY, then 41 strikes centred on prevClose stay fixed when spot moves 3 strikes; prices ≥ 0.05 on tick; options frozen in pre-open.
#### S-25 · Broker v2 and `OrderRepository` · dev-realtime · L · FR-31, FR-32…34, FR-37, FR-39a, FR-41, FR-122 (AC3), TR-10, TR-20, NFR-9, D8 · dep S-6, S-8, S-10a
- Files: `broker.dart`, `rest_api.dart` (orders), `features/orders/domain/{order,order_request,place_outcome}.dart`, `features/orders/data/**`.
- AC1: Given band 80.00–120.00, then 120.05 and tick 101.03 are rejected; CNC sell above held → `insufficient_holdings`; MIS and CNC RELIANCE stay 2 positions.
- AC2: Given a replay with the same key, then 1 order; `version` is monotonic; a pre-open limit queues and fills at 09:15.
- AC3: Given `dropAckAfterStore`, then 1 order stored, `GET /orders?key=` finds it, a same-key retry returns the same order.
#### S-24 · Chain channel and `ChainRepository` · dev-realtime · L · FR-29a, FR-23 (data), TR-7, TR-8, D6 · dep S-23, S-10a (after S-25 in queue)
- Files: `chain_book.dart`, `ws_gateway.dart` (chain), `features/options/domain/**` (not `chain_column.dart`), `features/options/data/**`.
- AC1: Given a chain subscribe, then ack + range snapshot, then changed-only deltas; iv/delta ≤ 1 Hz; a 3rd chain → `too_many_chains`.
- AC2: Given a `ka` view, when folded, then rows are identical and only `asOf` changes.
#### S-26 · Expiry settlement and MIS square-off · dev-realtime · M · FR-49, FR-29c, FR-44 (S) · dep S-25, S-23
- Files: `expiry_service.dart`, scheduler hook in `clock_scheduler.dart`.
- AC1: Given an open option at 15:30 on expiry day, then it settles at intrinsic (₹6,500 example) once, even after a replayed jump; chain status → expired.
- AC2: Given 15:19:50 + 10 s, then MIS positions square off with order frames; CNC/NRML untouched.
#### S-49 · Server load flag for perf runs · dev-realtime · S · NFR-4, NFR-5 (setup) · dep S-23
- Files: `bin/server.dart`, `market_engine.dart` (load mode).
- AC1: Given the load flag, then every equity and option contract trades each step (watchlist rows and 41 strikes at 4 Hz).
#### S-28a · Order ticket form and send-time stale block · dev-trading · M · FR-30, FR-32…34, FR-37, FR-38, FR-92, FR-70 (Payoff link), NFR-8, TR-6 · dep S-25, S-9, S-16, S-3
- Files: `order_ticket_sheet`, `order_ticket_state`, `order_ticket_controller` (form part), `widgets/**`, `orders/domain/{order_draft,order_validator,confirm_block}.dart`.
- AC1: Given two taps 50 ms apart, then 1 `place`; stale at 5.1 s (FakeClock) → 0 POSTs with reason; 4.9/5.0 s → POST; stale arising inside `confirm()` → 0 POSTs.
- AC2: Given an option at 09:14:59.900, then "Options open at 09:15", enabled at 09:15:00.000 without reopen; a plain ack goes Idle → Placing → Placed/Rejected.
- AC3: Given `insufficient_holdings`, `market_closed` or `price_band`, then an inline banner; Payoff opens the builder with 1 leg (fake opener until S-34).
#### S-28b · Submit retries, checking status, Pending · dev-trading · M · FR-31, FR-31a (sheet), FR-38a, NFR-10 · dep S-28a, S-8, S-25
- Files: `orders/domain/{submit_phase,ticket_event}.dart`, `order_ticket_controller` (submit part).
- AC1: Given `dropAckAfterStore`, then "Placing… checking status" after 3 s, ≤ 2 same-key retries, early `clientKey` match, 1 order on the server.
- AC2: Given 3 timeouts, then `getOrder(clientKey)` then a Pending row + snack; stale after the POST does not cancel it (FR-38a).
#### S-27 · Option chain screen · dev-trading · L · FR-20…25, FR-29b (S), FR-29c (UI), NFR-5 · dep S-24, S-16, S-13, S-12
- Files: `features/options/presentation/**` (not S-29 sheets), `features/options/domain/chain_column.dart`.
- AC1: Given 41 rows, when spot moves 3 strikes, then rows and scroll offset are unchanged and 2 strike cells rebuild; a `ka` view → 0 rebuilds.
- AC2: Given open or expiry change, then ATM sits at 55 % of the viewport; after 10 rows "Back to ATM" recentres.
- AC3: Given expiry day + debug next day, then the next expiry within 1 s; the last viewed underlying reopens (`LocalPrefs`); no saved selection shows the chooser without loading a guessed chain.
#### S-29 · Chain cell actions, greeks, add to strategy · dev-trading · M · FR-26, FR-27 (S), FR-29 (S), D5 · dep S-27, S-28a, S-3
- Files: `features/options/presentation/widgets/{cell_action_sheet,greeks_sheet}.dart`.
- AC1: Given a cell → Buy, then the ticket opens prefilled 1 lot NRML with contract and side.
- AC2: Given a draft of another chain, then "Add to strategy" shows "Start new" and the draft is unchanged.
#### S-30 · F&O risk notice · dev-trading · S · FR-113 · dep S-28a, S-12
- Files: `features/orders/presentation/risk_notice_screen.dart`, `core/navigation/openers.dart` (risk gate in `openOrderTicket`).
- AC1: Given a first F&O ticket, then the notice shows; Not now → shows again; I understand → never again until reset.
#### S-31 · Order outcome listener and haptics wiring · dev-trading · S · TR-21, NFR-10 (haptics), FR-102 (pref) · dep S-15, S-25, S-12, S-28b
- Files: `app/order_outcome_listener.dart`.
- AC1: Given a fill live and again after resync, then 1 snack and 1 `success`; a rejection → 1 `rejection`; haptics off → 0 calls.
#### S-32 · AI chat controller, screen and cards · dev-ai · L · FR-60, FR-62, FR-64 (C6), FR-65, FR-66 (C) · dep S-22
- Files: `features/ai_chat/presentation/**` (not `live/`, `ai_action_runner.dart`).
- AC1 (W1, C4): Given a fake stream, then card 1 paints while open, Send shows Stop; 5 deltas in 50 ms → 1 update; error after card 2 → 2 cards + interrupted.
- AC2 (W2, C6): Given any card incl. `UnknownCard`, then the footer reads exactly "Simulated. Not advice." (PRD v1.3); no order/alert repository imports.
- AC3 (C5, W6): Given stop/retry/51st answer, then cards kept / replaced in place / oldest dropped; off-bottom new card → "New answer" pill, offset unchanged.
#### S-33 · `LiveWhenVisible`, live cards, action buttons · dev-ai · M · FR-63, FR-64, NFR-7, NFR-14 · dep S-32, S-13, S-10b
- Files: `features/ai_chat/presentation/live/**`, `features/ai_chat/presentation/ai_action_runner.dart`.
- AC1 (W3): Given a card 60 % visible, then `liveQuoteProvider` has a listener; 40 % → none after 200 ms; tab hidden → none.
- AC2 (W5): Given "Trade this strike", then the opener gets `OrderTicketArgs(lots: 1, limitPrice: null, source: ai)`; `place` count 0.
- AC3 (W4): Given a snapshot `asOf` 5.1 s old with no live frame, then `StaleBadge`; at 5.0 s → live.
#### S-34 · Strategy builder and `PayoffChart` · dev-ai · L · FR-70, FR-71, FR-72, FR-73 (S) · dep S-19, S-3, S-6, S-24 (fake `ChainFeed` until done)
- Files: `features/strategy/**` (real `openStrategyBuilder`, needed before S-28a's Payoff link ships).
- AC1 (W8): Given one leg from the ticket, then a hockey stick; straddle → V (goldens both themes); chips show max loss in ₹.
- AC2 (W10): Given a stale leg, then the today line hides with a reason; a 5th add → "Up to 4 legs in preview".
- AC3 (W9, W11): Given a crosshair drag or tap, then the label follows inside 360 dp and haptics fire only on breakeven crossings; the strategy route sets `ScreenId.strategy` visibility.
#### S-35 · More shell, haptics toggle, debug overlay · dev-perf · M · FR-102 (S), FR-114 (S) · dep S-13, S-12
- Files: `features/more/presentation/**`.
- AC1 (T21, T22): Given haptics off, then `hapticsEnabled == false` and persists; overlay on → timings and FPS text.
#### S-36 · Subscription lifecycle integration tests · dev-perf · M · FR-85, FR-86, NFR-14, TR-11 · dep S-8, S-10b, S-13, S-17, S-18
- Files: `integration_test/lifecycle/**`.
- AC1 (T15, T16): Given a stock page over the watchlist, then after 400 ms `/debug/subscriptions` shows watchlist ids released; a tab flip in 200 ms → 0 unsubscribes.
- AC2 (T17): Given lifecycle hidden, then 0 subs and socket closed within 2 s, 0 reconnects for 10 s; shown → restored once.
#### S-48a · Perf harness skeleton (non-gating) · dev-perf · S · NFR-4 (method), FR-125 · dep S-17
- Files: `test_driver/perf_driver.dart`, `tool/perf/frames.sh`, `integration_test/perf/watchlist_perf_test.dart`.
- AC1: Given the Pixel 6a on normal ticking, when `frames.sh watchlist` runs, then a `timeline_summary.json` is written; the result is reported, never gating.

### Wave 3: M-C portfolio + alerts, M-D AI on live data
#### S-37 · Holdings, funds, T+1, `PortfolioRepository` · dev-realtime · M · FR-45 (data), FR-39 (S), FR-46 (S), D3 · dep S-25
- Files: `broker.dart` (books), `rest_api.dart` (portfolio), `features/portfolio/data/**`.
- AC1: Given a CNC buy, when the day rolls, then it moves to holdings; funds debit on fill, credit on sell; `current` returns a `PortfolioBook`.
#### S-38 · Alerts engine and `AlertsRepository` · dev-realtime · M · FR-50, FR-51, FR-54, FR-55 · dep S-37, S-10a, S-12
- Files: `alerts_engine.dart`, `rest_api.dart` (alerts), `features/alerts/{domain,data}/**`.
- AC1: Given an above alert, when price crosses, then one `alert.triggered` with `alertId` + `triggeredAt`; none while Closed.
- AC2: Given the same `alertId` live and after resync, then `triggered` emits once and the id is in the seen-set.
#### S-39 · `MarketReads` and AI mount · dev-realtime · M · D12, R1, FR-61 (data), FR-124 · dep S-24, S-21
- Files: `market_reads.dart`, `market_server.dart` (`mountAiApi` call), `debug_api.dart` (`activeAiAnswers`).
- AC1: Given a fixed OI fixture, then PCR, max pain and `strikeStep` are correct; the facade has no mutators.
- AC2: Given the real server, when one ask runs, then it streams `start` → `done`; `/debug/subscriptions` shows `activeAiAnswers` 1 then 0.
#### S-40 · Resync reloaders and restart reliability · dev-realtime · M · FR-84 (REST), TR-9, NFR-10, NFR-11 · dep S-37, S-38
- Files: reloader registration in `portfolio/alerts` data, `integration_test/realtime/{resync,restart,freeze}_test.dart`, delete `core/providers.dart`.
- AC1: Given skip-seq, then fills and alerts count = 1 and `resyncCompleted` fires after orders, positions and alerts reload.
- AC2: Given 20 kill + re-serve loops, then Live ≤ 10 s each time and positions equal the server.
#### S-41 · Debug clock screen and Socket Lab · dev-perf · M · FR-110, FR-111 · dep S-8, S-35
- Files: `features/more/{debug_clock,socket_lab}/**`.
- AC1: Given preset 15:19:50, then the clock jumps; a backward preset shows "Going back resets the demo account" and calls `reset`.
- AC2: Given 600 frames, then the ring holds the last 500; the screen sits under More › Developer.
#### S-42 · Portfolio screen and summary · dev-trading · L · FR-40…43, FR-45, FR-47, FR-48, FR-49 (UI), FR-31a (Pending row) · dep S-37, S-26, S-28b, S-12, S-13 (resync AC: S-40)
- Files: `features/portfolio/presentation/**`, `features/portfolio/domain/portfolio_summary.dart`.
- AC1: Given MIS + CNC RELIANCE, then 2 rows; Exit on a 2-lot long → sell 2 lots prefilled; summary sums equal rows.
- AC2: Given 15:20 and 15:30 debug jumps, then MIS closes with a notice and settlement books ₹6,500 realised.
- AC3 (integration, after S-40): Given a Pending row, when resync completes, then it shows the final status; Refresh is disabled Offline.
#### S-43 · Alerts UI and banner queue · dev-trading · M · FR-50 (UI), FR-52, FR-53 (S), FR-55 (UI) · dep S-38
- Files: `features/alerts/presentation/**`, `app/alert_banner_host.dart`, `core/navigation/openers.dart` (`openAlertCreate`).
- AC1: Given an order sheet open when an alert triggers, then no banner and a bell dot; on close → banner; tap → stock page.
- AC2: Given Above below LTP, then a create error; the same `alertId` twice → 1 banner.
#### S-44 · SL orders, nudges, funds · dev-trading · M · FR-35 (S), FR-36 (S), FR-39 (S) · dep S-28a, S-37
- Files: `widgets/nudge_strip.dart`, SL and funds rules in `order_validator.dart`, funds row in `widgets/summary_rows.dart`.
- AC1: Given a buy SL with trigger > limit, then a validation error; nudges are soft and dismissible.
- AC2: Given funds below the order value, then "Funds available" shows it and the server's `insufficient_funds` shows inline with 1 `rejection`.
#### S-45 · AI end to end on live data (J-4) · dev-ai · M · FR-61, FR-63, FR-64, FR-72 · dep S-39, S-33, S-34
- Files: `integration_test/ai/**`.
- AC1 (I1): Given 2 RELIANCE cards, then 1 server quote sub; both scrolled off → 0 within 1 s.
- AC2 (I2): Given chip "What does the NIFTY chain say?", then quote + chain + text; View payoff → max loss; Trade this strike → "From AI chat"; 0 POSTs.
#### S-46 · Reset demo account and warm start · dev-perf · S · FR-112 (S), FR-80, FR-81 · dep S-8, S-35, S-42 (`PortfolioSummary.compute`)
- Files: `features/more/presentation/more_controller.dart`, `core/storage/snapshot_scheduler.dart`.
- AC1: Given reset, then server reset, snapshot and prefs cleared, risk notice shows again; offline → disabled "Needs connection".
- AC2 (T18, T24): Given a warm cache and no server, then cached lists paint, badge Offline, no save on hide; the seeded summary equals `PortfolioSummary.compute`.

### Wave 4: device performance and polish (E11)
#### S-47 · Startup runs on device · dev-perf · M · NFR-1, NFR-2, NFR-3, NFR-15 · dep wave 3 done
- Files: `tool/perf/{startup.sh,summarize.dart}`, `docs/perf-results.md`.
- AC1: Given 10 cold and 10 warm runs on the Pixel 6a, then p50/p90 rows are appended with device, OS, SHA, date, pass/fail.
#### S-48 · Frame, latency and memory runs · dev-perf · M · NFR-4, NFR-5, NFR-6, NFR-16 · dep S-48a, S-49, wave 3 done
- Files: `integration_test/perf/{chain_perf_test,startup_probe_test}.dart`, `tool/perf/frames.sh` (gating modes).
- AC1: Given 5 runs each under the load flag, then median p90 build and raster < 16.7 ms, missed ≤ 1 %; probe p90 ≤ 50 ms; chain RSS ≤ 250 MB.
#### S-50 · Trading accessibility sweep · dev-trading · M · NFR-12, NFR-13 · dep S-42, S-43
- Files: `test/a11y/trading/**`, fixes in dev-trading files.
- AC1: Given 360×800 at 2.0×, then watchlist, chain, ticket and portfolio have no overflow and pass contrast and tap-target guidelines.
#### S-51 · AI accessibility and chat perf scenario · dev-ai · S · NFR-12, FR-125 · dep S-45, S-48a
- Files: `test/a11y/ai/**`, `integration_test/perf/chat_perf_test.dart`.
- AC1: Given every card type and the builder at 2.0×, then `takeException` is null; `ai_first_card_painted` and `ai_stream_done` marks appear.

## 2a. CR-1 notes on existing stories (v2.0)

**All remaining stories:** controllers + `*_state.dart` in `application/`; repositories are domain interfaces with
`Live*` in `data/`; DI in `<f>_providers.dart`; `Success` / `Failure` with `AppError` (`NetworkError`, `ServerError`,
`ParseError`) replace `Ok` / `Err` / `*Failure`; navigation via `<f>_routes.dart` on go_router (no `core/navigation`);
messages only via `FeedbackController.show(key, …)`; text via `AppStrings`, icons via `AppIcons`; choice controls via
`SpPicker`; files ≤ 300 lines; 100 % coverage of the story's files; each story logs its FR-187 catalogue events once R-5
has landed (fake sink in tests). Story-specific changes:

| Story | CR-1 change |
|---|---|
| S-8 | Files → `core/network/data/debug_client.dart` + `network_providers.dart`; 409 maps to `ServerError(409, 'backward_jump_requires_reset')` |
| S-9 | Files → `core/market_time/{domain,data,application}/**`, `core/network/application/network_status.dart`; dep R-1b |
| S-10a | Files → `core/network/data/{market_socket,frame_decoder,subscription_book,socket_messages}.dart` (R-1b split), `core/network/application/resync_coordinator.dart`; dep R-1b |
| S-10b | `MarketRepository` interface in `market/domain`, `LiveMarketRepository` in `data/`, `market_providers.dart`; `liveQuoteProvider` in `market/application/live_quote_provider.dart`; dep R-1b, R-4 (not S-4 lifecycle) |
| S-13, S-14 | **Dropped** (V2): S-13 → R-4, S-14 → R-0. Every "dep S-13" below now reads "dep R-4" |
| S-17 | `watchlist_controller` + state in `market/application/` (R-2 moved them); long-press sheet strings in `MarketStrings`; dep R-2, R-4; `watchlist_row_action` logged here if R-5 is in, else in S-60 |
| S-18 | Stock page sections only (R-2 split); interval and chart type use `SpPicker` (**dep S-59**); the chart itself moves to `features/chart/` in S-53, which keeps AC2's `interactive` / `showVolume` flags |
| S-22 | Files → `core/network/data/api_client_lines.dart`, `ai_chat/{domain,data}`; AC1 reads `ServerError` / `NetworkError`; `AiRepository` interface from R-3 |
| S-23…S-26, S-37, S-38 | Interfaces in `domain/`, `Live*` in `data/`, feature DI file; server files ≤ 300 lines (split `broker.dart`, `chain_book.dart` if they grow) |
| S-27 | `chain_controller` + state in `options/application/`; chain columns picker is `SpPicker` (multi); route `/options?u&e&k&r`; dep R-4 (not S-13) |
| S-28a | Ticket controller + state in `orders/application/`; order type and product are `SpPicker` segmented; a tap on disabled Confirm = reason focus + haptic, **no snackbar** (UX part 12); Payoff link via `strategy_routes.dart`; logs `order_sheet_opened`, `order_confirm_tapped`, `order_blocked_stale` |
| S-28b | Pending notice via `FeedbackController` key `orders.status_unknown.<clientKey>`, order-outcome priority (FR-157); logs `order_result` |
| S-29 | "Start new" is a `FeedbackController` message with an action (key `strategy.other_chain`), reply handled by `StrategyDraftController` |
| S-30 | Risk notice is the `/risk-notice → bool` route; gate lives in `orders_routes.dart` (not `core/navigation/openers.dart`); logs `risk_notice_shown` / `risk_notice_ack` |
| S-31 | `app/order_outcome_listener.dart` stays dev-trading; snacks go through `FeedbackController` with order-outcome priority, 1 per `orderId` |
| S-32 | Chat controller born in `ai_chat/application/`; footer text from `AiStrings`; logs `ai_question` (intent only, FR-188) |
| S-33 | Action runner calls `<f>_routes` helpers; visibility from `core/visibility`; dep R-4 (not S-13); logs `ai_card_action` |
| S-34 | Uses R-3's `StrategyDraftController`; route `/strategy`; dep R-3 |
| S-35 | More is shell branch 4 `/more`; settings rows host S-74 and S-75 later; dep R-4 (not S-13) |
| S-36 | dep R-4 (not S-13); observer is `VisibilityRouteObserver` |
| S-40 | Drop "delete `core/providers.dart`" (done in R-1a) |
| S-41 | `socket_lab` already moved in R-4; routes `/more/socket-lab`, `/more/clock`; not reachable by link in release (FR-178) |
| S-42 | Portfolio controller already in `application/` (R-2); route `/portfolio?tab`; refresh errors via `FeedbackController` |
| S-43 | Alert direction is `SpPicker`; `openAlertCreate` in `alerts_routes.dart`; after the first created alert call `pushPermissionController.afterFirstAlert()` (R-5 stub, S-74); logs `alert_created`, `alert_opened` |
| S-44 | SL order type joins the order-type `SpPicker` |
| S-46 | Reset also calls `ChartStore.clearAll()` (S-56) and `AnalyticsService.reset()`; dep S-56 |
| S-47 | Adds NFR-22 checks: push and analytics init after the first frame, native splash only (S-61) |
| S-48 | Chart scenario is a separate story S-76 |
| S-50 | Sweep adds chart toolbar, Studies sheet, drawings handles, landscape chart and `SpPicker` |
| S-51 | AI area strings complete (S-67 checks clean for `ai_chat`, `strategy`) |
| R-2 | Acceptance for FR-156 / FR-157 (one snackbar, same key dropped < 4 s, priority) lives here; `core/l10n` + `core/assets` kits |
| R-5 | Acceptance for FR-175…180 and FR-185…188; analytics listens to `networkStatusProvider` for `connection_changed` (no edit of realtime files); stub `PushPermissionController.afterFirstAlert()`; chart link `/stock/{symbol}/chart` tested in S-57 |

## 3. Waves (v2.0)

Done: W0 (S-1…S-4). In review, closed on v1.1 rules: S-5, S-6, S-7, S-11, S-12, S-15, S-16, S-19, S-20, S-21.
**Bold** = new in v2.0 (cr1.md). Arrows are queue order per owner; a story starts when its deps are done.

| Wave | dev-realtime | dev-trading | dev-ai | dev-perf | Exit |
|---|---|---|---|---|---|
| W1R Refactor | R-1a (alone) → R-1b | R-2 | R-3 | R-0 (alone, first) → R-4 | `06-lld/README.md` §6.3: gates blocking (file length, deny-list, `--fatal-infos`, layer test, coverage 100 %) |
| W1 rest M-A | S-9 → S-10a → S-10b → S-8 | **S-59** → S-18 → S-17 | S-22 → **S-52** | **S-61** | M-A tests green; FR-120…126 live; icon + splash in builds |
| W2 M-B | S-23 → S-25 → S-24 → S-26 → S-49 | S-28a → S-28b → S-27 → **S-53** → S-29, S-30, S-31, **S-68** | S-32 → S-33, S-34 | R-5, S-35, S-36, S-48a, **S-67** | J-2 passes; deep links + analytics live; chart module on the stock page |
| W3 M-C/D + chart | S-37 → S-38 → **S-56** → S-39 → S-40 | S-42 → S-43 → **S-55** → **S-57** → S-44 → **S-60** | S-45, **S-54** → **S-70**, **S-66** | S-41, S-46, **S-65**, **S-74**, **S-75** | J-3, J-4, J-5 pass; chart Musts FR-130…144 green; no-dropdown gate blocking |
| W4 Perf + polish | **S-63**, perf fixes as raised | **S-58** → **S-72** → **S-73** → **S-64** → **S-69** → S-50 | S-51, **S-71** | **S-62**, S-47, S-48, **S-76** | NFR table filled (incl. NFR-22, NFR-23); §7a trace 0 gaps; string / asset / formatter gates blocking |

**Why this order.** The SpPicker (S-59) goes first in dev-trading's W1 queue because S-18 is the first screen with choice
controls; icon + splash (S-61) needs only R-0 and fills dev-perf's W1 slot left by the dropped S-13/S-14. Indicator maths
(S-52) is pure Dart, so dev-ai builds it in W1 with no screen deps. The chart module (S-53) waits for the order ticket so the
critical path S-28a → S-28b is not delayed. `ChartStore` (S-56) sits after S-38 so the alerts path (S-38 → S-43) is not
delayed, and before S-55 needs a real store. Buy / Sell from the chart (S-58) is in W4 because it needs the landscape route
(S-57, late W3); it is a Must, so it is first in dev-trading's W4 queue. Network failure tests (S-63) need S-40's reloaders.

**Load.** dev-trading carries the most (12 v1.1 stories left + R-2 + 11 new, 4 of them S); S-71 moved to dev-ai (D16). If W3
slips, S-44 (Should) moves to v2.1 first.

**File-overlap check per wave (across owners): none.** New paths only; v1.1 lists above still apply.
- W1R: as `06-lld/README.md` §6 (R-0 and R-1a run alone; after R-1a no file has two owners).
- W1: realtime `core/network/**` (not `api_client_lines.dart`), `core/market_time/**`, `market/{domain,data}`, `market_providers.dart`, server `debug_api.dart`; trading `core/widgets/sp_picker/**`, `core/assets/app_icons.dart`, `core/l10n/strings/common_strings.dart`, `market/{application,presentation}`; ai `ai_chat/{domain,data}`, `core/network/data/api_client_lines.dart`, `chart/domain/indicators/**`, stubs in `chart/{application,presentation}/studies/**`, `chart/domain/fib_levels.dart`, `chart/presentation/drawings/fib_painter.dart`, `core/l10n/strings/studies_strings.dart`; perf `tool/brand/**`, `tool/ci/brand_check.dart`, `android/app/src/main/res/**`, `ios/Runner/{Assets.xcassets,Base.lproj/LaunchScreen.storyboard}`. (S-15's `AndroidManifest.xml` / `MainActivity.kt` are not touched by S-61.)
- W2: realtime server option/pricer/chain_book/broker/expiry, `market_engine.dart` + `bin/server.dart` (S-23 then S-49), `options` + `orders` domain/data; trading `orders` + `options` application/presentation, `orders_routes.dart`, `app/order_outcome_listener.dart`, `chart/{domain/(chart_layout,drawing,chart_range),application/chart_*,presentation/*}` (not `studies/`), `stock_detail_screen.dart`, `core/format/**`, `core/assets/app_images.dart`, `chart_strings`; ai `ai_chat/{application,presentation}`, `strategy/**`; perf `core/{analytics,push}/**`, `app/router/deep_link.dart`, `app/push_link_handler.dart`, `AndroidManifest.xml` + `Info.plist` (link filters, R-5), `features/more/**`, `integration_test/lifecycle`, `test_driver/`, `tool/perf/frames.sh`, `tool/ci/{string_literal,asset_registry,formatter,no_dropdown}_check.dart`.
- W3: realtime alerts engine, `portfolio` + `alerts` domain/data (not `portfolio_summary.dart`), `market_reads.dart`, `market_server.dart`, `debug_api.dart`, `integration_test/realtime`, `chart/{domain/chart_store.dart,data/**,chart_providers.dart}`; trading `portfolio` + `alerts` application/presentation, `portfolio_summary.dart`, `alert_banner_host.dart`, `alerts_routes.dart`, `order_validator.dart` / `nudge_strip.dart` / `summary_rows.dart`, `chart/{domain/(drawing,drawing_geometry,tick_snap),application/drawings/**,presentation/(drawings/** not fib_painter,fullscreen/**),chart_view,chart_toolbar}`, `market_routes.dart`, `core/feedback/application/feedback_controller.dart` (S-60); ai `integration_test/ai`, `chart/{application,presentation}/studies/**`, `chart/domain/indicators/{bollinger,macd,study_catalog}`, `test/features/ai_chat/failures`; perf `features/more/{debug_clock,socket_lab,settings}/**`, `more_controller.dart`, `snapshot_scheduler.dart`, `core/push/application/push_permission_controller.dart`, `test/core/**/failures`, `test/app/router`, `integration_test/{startup,analytics}`, `tool/ci/failure_trace_check.dart`.
- W4: realtime `core/network/data/{api_client,retry_policy}.dart`, `test/core/network/failures`, `test/features/*/data/fixtures/bad`, `integration_test/realtime/failures`, `market_server/test/failures`; trading `chart/presentation/{chart_settings_sheet,candle_geometry,crosshair_layer,crosshair_menu,line_menu}`, `chart/application/chart_controller`, `chart/presentation/{drawings/drawing_action_bar,fullscreen/chart_trade_rail}`, `orders/presentation/order_ticket_side_sheet.dart`, `core/l10n/{locales/pseudo/**,app_strings_delegate.dart}`, `test/features/*/presentation/failures`, `integration_test/trading`, `test/a11y/trading`; ai `test/a11y/ai`, `chat_perf_test.dart`, `chart/domain/fib_levels.dart`, `chart/presentation/drawings/fib_painter.dart` (S-71; dev-trading does not touch them); perf `res/values-night*`, `LaunchBackground.colorset`, `LaunchScreen.storyboard`, `integration_test/perf/{chain_perf_test,startup_probe_test,chart_perf_test}.dart`, `tool/perf/**`, `docs/perf-results.md`.
- Cross-owner touch points are calls, not edits: S-53 mounts dev-ai's stub widgets; S-43 calls dev-perf's `afterFirstAlert()`; S-46 calls dev-realtime's `ChartStore.clearAll()`; R-5 listens to dev-realtime's `networkStatusProvider`.

Critical path: R-0 → R-1a → R-1b → S-10a → S-8 → S-25 → S-28a → S-28b → S-42 → S-64 → S-50; chain branch S-10a → S-23 → S-24 →
S-27; chart branch S-59 → S-18 → S-53 → S-55 → S-57 → S-58 → S-76.

**S-49 decision (v1.1, unchanged):** wave 2, dep S-23, last in dev-realtime's W2 queue; it lets S-48a smoke runs use real
4 Hz load a wave early.

## 4. Definition of done (v2.0)

1. Tests written first from the owner's LLD test table; the red run (test name + failure) is in the task note before green (NFR-20); each test names its FR/TR/NFR/F-row.
2. `flutter analyze --fatal-infos` and `dart analyze --fatal-infos` report 0 issues; `flutter test` and `dart test` pass in all three packages; file-length, deny-list, layer-rule and coverage (100 % lines, no ignore pragmas) checks green (NFR-19, NFR-24).
3. Manual Riverpod providers, hand-written immutable classes and JSON, no codegen (hand-written `AppStrings`, ADR-0018); state + controller in `application/`, widgets UI only (NFR-18, ER-1, ER-2).
4. Only the story's listed files changed; any §10.2 signature change went through the architect first.
5. Every acceptance criterion is an automated test; the Must-FR trace check (R-0) and, from W3, the §7a trace (S-65) stay green.
6. No narrating comments, `// S-n` tags or TODO prose (ER-4); user text in `AppStrings`, icons in `AppIcons`, messages via `FeedbackController`.
7. Dashboard task moved `todo → in_progress → review`, set `done` only by dev-lead or reviewer; slips posted in `planning`.

## 5. Coverage: Must FRs → stories (111)

| Area | Must FR → story |
|---|---|
| Watchlist | FR-1 S-17 · FR-2 S-16 · FR-3 S-6, S-17 · FR-5 S-17 · FR-6 S-6, S-18 · FR-7 S-6 |
| Stock page | FR-10 S-18, S-53 · FR-11 S-18, S-53 · FR-12 S-18 · FR-13 S-18 · FR-14 S-5, S-16 |
| Chain | FR-20 S-23, S-27 · FR-21 S-27 · FR-22 S-27 · FR-23 S-24, S-27 · FR-24 S-5, S-27 · FR-25 S-27 · FR-26 S-29 · FR-29a S-24 · FR-29c S-23, S-26, S-27 |
| Orders | FR-30 S-28a · FR-31 S-25, S-28b, S-63 · FR-31a S-28b, S-42 · FR-32 S-25, S-28a · FR-33 S-28a · FR-34 S-25, S-28a · FR-37 S-5, S-25, S-28a · FR-38 S-28a · FR-38a S-28b · FR-39a S-25, S-28a |
| Portfolio | FR-40 S-42 · FR-41 S-25, S-42 · FR-42 S-42 · FR-43 S-42 · FR-45 S-37, S-42 · FR-47 S-42 · FR-48 S-42 · FR-49 S-26, S-42 |
| Alerts | FR-50 S-38, S-43 · FR-51 S-38 · FR-52 S-43 · FR-54 S-38, S-40 · FR-55 S-38, S-43 |
| AI | FR-60 S-21, S-22, S-32, S-66 · FR-61 S-20, S-39, S-45 · FR-62 S-21, S-32 · FR-63 S-33, S-45 · FR-64 S-32, S-33, S-45 · FR-65 S-20, S-32 · FR-67 S-21, S-22, S-66 |
| Payoff | FR-70 S-19, S-28a, S-34 · FR-71 S-19, S-34 · FR-72 S-19, S-34 |
| **Chart (new)** | FR-130 S-54 · FR-131 S-52, S-54 · FR-132 S-52, S-54 · FR-133 S-52, S-54 · FR-134 S-52, S-54 · FR-138 S-52 · FR-139 S-53 · FR-140 S-55 · FR-141 S-55 · FR-143 S-53, S-55, S-56 · FR-144 S-57 · FR-145 S-58 |
| Startup/offline | FR-80 S-12, S-46 · FR-81 S-10b, S-17, S-46 · FR-82 **R-4** (was S-13) · FR-83 S-16 · FR-84 S-7, S-10a, S-40, S-63 · FR-85 **R-4**, S-36 · FR-86 **R-4**, S-36 · FR-87 S-12 |
| Stale | FR-90 S-10a, S-16 · FR-91 S-7, S-9, S-10b · FR-92 S-28a, S-58 · FR-93 S-7 · FR-94 S-9 · FR-95 S-7 |
| Platform/debug | FR-100 S-15 · FR-101 S-15 · FR-110 R-4, S-41 · FR-111 S-5, S-41 · FR-113 S-30, S-58 · FR-116 S-5 |
| Test hooks | FR-120 S-5 · FR-121 S-8 · FR-122 S-8, S-25 · FR-123 S-8 · FR-124 S-8, S-39 · FR-125 S-11 · FR-126 S-15 |
| **Feedback, picker (new)** | FR-155 S-59, S-53, S-60, S-67 · FR-156 R-2, S-64 · FR-157 R-2, S-31 |
| **Strings, assets (new)** | FR-160 R-2, S-67 (+ every story, DoD 6) · FR-161 R-2, S-68 · FR-162 S-68, S-67 · FR-163 R-2, S-67, S-68 |
| **Icon, splash (new)** | FR-170 S-61 · FR-171 S-61 |
| **Links, push (new)** | FR-175 R-4, R-5, S-53, S-57 · FR-176 R-5, S-57 · FR-177 R-5, S-65 · FR-178 R-5, S-41, S-58 · FR-179 R-5 · FR-180 R-5 |
| **Analytics (new)** | FR-185 R-5 · FR-186 R-5 · FR-187 R-5 + feature stories per §2a, verified by S-65 AC5 · FR-188 R-5, S-65 |

**Gaps: none** (80 v1.1 Must + 31 new = 111). Watch items, not gaps: FR-187 is spread over many owners (S-65 AC5 is the
single check); FR-160 / FR-157 wording settled by D17, D18 and PRD v1.5. **Should FRs scheduled:** v1.1 set (FR-4, 27, 29, 29b, 35, 36, 39,
44, 46, 53, 73, 102, 112, 114) plus FR-135, 136 S-70 · FR-142 S-71 · FR-146, 147 S-72 · FR-148, 149 S-73 · FR-164 S-69 ·
FR-172 S-62 · FR-181 S-74 · FR-189 S-75. **NFRs:** 1–3 S-47 · 4–6, 16 S-48 (S-48a, S-49) · 7 S-9, S-33 · 8 S-28a · 9 S-6,
S-25 · 10 S-28b, S-31, S-40 · 11 S-40, S-63 · 12 S-50, S-51, S-59 · 13 S-18, S-50 · 14 S-33, S-36 · 15 S-11, S-47 · 17,
18 **R-0** (was S-14) · 19 R-0 + DoD 2 · 20 DoD 1 · 21 S-63, S-64, S-65, S-66 · 22 S-61, S-47, R-5 · 23 S-57, S-76 · 24 R-0,
S-67. **§7a F-rows:** F1 S-64, S-65 · F2–F8 S-63 · F4 UI S-64 · F6 AI S-66 · F9 S-52, S-54, S-64, S-66 · F10 S-65, S-74 ·
F11 S-55, S-56, S-65 · F12 S-64 · F13 S-65, S-66 · F14–F16 S-65 · F17 S-64 · F18 S-68.

## 6. Backlog (not scheduled)

| Item | Reason |
|---|---|
| FR-28 PCR and max-pain on the chain header | Could; deferred to v2.1 by D13 (AI chain card still shows PCR) |
| FR-137 Supertrend, FR-150 hollow candles, FR-151 compare, FR-152 prev / next symbol | Could; v2.1 per PRD §8 (M-E lists Musts first) |
| Chart Later list (Renko, extra intervals, layouts, order lines, GTT) | PRD §4.8a Later |
| BANKNIFTY underlying | v2.1 list in PRD §8; out of v2 scope (D-1) |

## 7. Open questions

1. ~~Architect: ack S-41 moving to dev-perf (C5).~~ Closed: approved (C12).
2. ~~Architect: confirm `features/chart/` as a new feature folder with the file split in cr1.md §2 (HLD §4.1 lists no chart feature).~~ Closed: D14.
3. ~~dev-ai to take S-71?~~ Closed: yes, D16 (Fib files only).
4. ~~FR-160 ARB vs ADR-0018.~~ Closed: D18, PRD v1.5.
5. ~~FR-157 vs ADR-0019.~~ Closed: D17, FR-157 wins (R-2).
6. ~~Q-UX-1, Q-UX-3.~~ Closed: both accepted (PRD v1.5).
