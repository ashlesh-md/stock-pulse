# 06 · LLD index and review (architect)

Status: LLD review round + **CR-1 impact (§6)** · Binding interfaces: `05-hld.md` §10.2 **v2.0** (v1.1 history kept) · Rule: an LLD cites §10.2 verbatim; any change goes through the architect first.

## 1. Index

| File | Author | Scope (HLD §10.1) | Review result |
|---|---|---|---|
| `realtime.md` | dev-realtime | server modules, protocol v2, clocks, pricing, settlement, debug hooks, socket client, repositories, `option_math/pricing.dart` | **edits needed** (R1–R6) |
| `trading.md` | dev-trading | theme, openers, watchlist, stock page, chain, ticket, risk notice, portfolio, alerts, haptics | **edits needed** (T1–T8) |
| `ai.md` | dev-ai | `ai/` server, NDJSON, `postLines`, chat, cards, `LiveWhenVisible`, builder, `PayoffChart`, `option_math/payoff.dart` | **edits needed** (A1–A6) |
| `perf.md` | dev-perf | `main()`, `AppShell`, visibility, storage, observability, perf harness, More shell | **edits needed** (P1–P3, small) |

## 2. Decisions on the LLD questions (folded into HLD §10.2 v1.1)

| # | Question (from) | Decision | Why |
|---|---|---|---|
| D1 | Tab switch API for `openChain` (trading) | Use dev-perf's existing `appShellControllerProvider.notifier.select(ScreenId)`; no `shellTabProvider` | One owner of shell state; perf.md already defines it |
| D2 | Missing repository calls (trading) | Approved as additions, with **dev-realtime's names**: `getInstrument(id)`, `getInstruments`, `watchPositions/Holdings/Funds`, `get*`, `settlements`, `getOrders`, `cancel`, `AlertsRepository.list/create/delete/watchAll` | realtime.md already implements them; consumers adopt its names |
| D3 | Snapshot needs data (perf) | Approved: `MarketRepository.watchlistIds` (+ `setWatchlist`), `latestQuotes(ids)`, `PortfolioRepository.current` → `PortfolioBook`. `PortfolioSummary` is **not cached**: it is derived by the pure `PortfolioSummary.compute(...)` (dev-trading) on seed | Snapshot holds facts, not derived numbers; no third JSON owner |
| D4 | Two stacked stock pages (perf) | Approved: `openStock` uses `pushReplacement` when the top route is `stockDetail`; all openers set `RouteSettings(name: ScreenId.x.name)` | Keeps `screenVisibleProvider` keyed by enum; matches UX "≤ 2 levels" |
| D5 | `addLeg` premium / other chain (ai) | Approved: `addLeg(contractId, side, double premium)` → `added | full | otherChain`; `otherChain` changes nothing, caller shows snack "Strategy uses NIFTY 10 Nov · Start new" whose action calls `clear()` then `addLeg` | The cell knows its LTP; silent clearing of a draft is data loss |
| D6 | `ChainRequest` fields/throttle; iv for the builder (realtime, ai) | `ChainRequest` stays 4 fields; chain throttle fixed at 250 ms; `iv` and `delta` always present on `OptionCell`, refreshed ≤ 1 Hz | One wire shape; column picker and today line both work; cost ≤ 1 Hz |
| D7 | Backward debug jumps (realtime) | Approved: `POST /debug/clock` backward → 409 `backward_jump_requires_reset`; `POST /debug/reset {time}`; `DebugClient.setClock/reset` added. Debug clock screen: backward presets (e.g. 09:14:50 from 10:00) show "Going back resets the demo account" and call `reset` | Scheduler replays forward only; reset is the honest way back |
| D8 | `place` attempts (realtime) | Approved: `place` = one attempt; ticket owns ≤ 2 same-key retries with `CheckingStatus` | Retry state is UI-visible (FR-31a); one owner |
| D9 | `ka` emissions (realtime) | Approved: `ka` re-emits quotes equal by `==` with a new `asOf`; widgets select price fields or `Freshness`, never `asOf` | Freshness sees the new `asOf`; price widgets do not rebuild (ADR-0003) |
| D10 | Alert direction naming (review) | `AlertArgs.condition: AlertCondition?` (`above`, `below`), the server enum; `AlertDirection` removed | One enum client and server |
| D11 | `api_client.dart` had two owners (review) | dev-realtime owns the file and adds `send(BaseRequest)`; dev-ai's `postLines` is an `extension ApiClientLines` in `core/network/api_client_lines.dart` | No shared file |
| D12 | `MarketReads` shape (ai) | realtime.md §3.8 is binding (now in §10.2), plus `ChainRead.strikeStep`; ai.md adopts `List<Instrument>`, `List<Candle>`, `wallNow/marketNow/phase` instead of `InstrumentInfo`/`CandleRead`/`clock()` | Producer's shape is already designed and tested |
| D13 | FR-28 PCR / max pain on the chain header (Could) | **Deferred to v2.1**; not in `ChainView` v1.1. The AI chain card still shows PCR via `MarketReads` | Could priority; avoids a new wire field now |

## 3. Consistency table

| # | Issue | LLD | Fix | Owner |
|---|---|---|---|---|
| R1 | `ChainRead` lacks `strikeStep` that ai needs | realtime §3.8 | add `strikeStep` | dev-realtime |
| R2 | `api_client.dart` listed for both realtime and ai | realtime §1.3 | own the file, add `send(http.BaseRequest)` with auth header; note `postLines` lives in `api_client_lines.dart` (dev-ai) | dev-realtime |
| R3 | Snapshot getters missing | realtime §7.5 | add `watchlistIds`, `setWatchlist` (→ `markStructuralDirty`), `latestQuotes`, `PortfolioBook` + `current`; `Position/Holding.toJson/fromJson` | dev-realtime |
| R4 | No client debug API for reset / clock | realtime §1.3, §7 | add `DebugClient` (`setClock`, `reset`) and the backward-preset confirm in the debug clock screen | dev-realtime |
| R5 | FR-110 Socket Lab not traced | realtime §1.3, §9 | trace FR-110: frame ring capped at 500, moved under More › Developer | dev-realtime |
| R6 | `option_math.dart` barrel marked "shared" | realtime §1.1 | owner = dev-realtime (barrel only exports) | dev-realtime |
| T1 | `shellTabProvider` gap | trading §4, §13 | use `appShellControllerProvider.notifier.select(ScreenId.options)` after `popUntil` first route | dev-trading |
| T2 | `MarketRepository.instrument(id)` | trading §13 | `getInstrument(id)` | dev-trading |
| T3 | `Stream<Position>` / `Stream<double> funds` | trading §8, §13 | `watchPositions()`, `watchHoldings()`, `watchFunds(): Stream<Funds>`, `settlements` | dev-trading |
| T4 | `ChainRequest(underlying, expiry, from:, to:)` | trading §6 | `ChainRequest(underlying: …, expiry: …, fromStrike: …, toStrike: …)` | dev-trading |
| T5 | `openStock` plain push; routes unnamed | trading §4 | `pushReplacement` when top is `stockDetail`; `RouteSettings(name: ScreenId.x.name)` on every pushed route | dev-trading |
| T6 | "Add to strategy" call lacks premium/result | trading §6 | `addLeg(contractId, side, cell.ltp)`; handle `full` and `otherChain` snacks (D5) | dev-trading |
| T7 | `AlertArgs.direction` / alert create | trading §9 | `condition: AlertCondition?`; `AlertsRepository.create(symbol, cond, level)` | dev-trading |
| T8 | Summary + FR-83 trace | trading §8, §11 | provide pure `PortfolioSummary.compute(positions, holdings, quotes)` (used by perf seed too); trace FR-83 on `ConnectionBadge` | dev-trading |
| A1 | `addLeg` interim behaviour | ai §0, §7 | cite v1.1 signature; `otherChain` changes nothing; drop "clears the draft" | dev-ai |
| A2 | `MarketRepository.instrument(id)` | ai §7 | `getInstrument(id)` | dev-ai |
| A3 | `MarketReads` assumed shape | ai §1 | adopt realtime §3.8 / HLD §10.2 (D12) | dev-ai |
| A4 | `AlertArgs.direction` | ai §0, §5 | `condition: null` | dev-ai |
| A5 | `openStrategyBuilder` route unnamed | ai §7 | `MaterialPageRoute(settings: RouteSettings(name: ScreenId.strategy.name), …)` | dev-ai |
| A6 | `postLines` file | ai §3.1 | `extension ApiClientLines` in `core/network/api_client_lines.dart` over `ApiClient.send` | dev-ai |
| P1 | `summary` in `snapshot.json` | perf §4.2 | remove `summary` from schema and `AppSnapshot`; seed computes via `PortfolioSummary.compute` | dev-perf |
| P2 | §11 requests now decided | perf §11 | replace with the v1.1 names (D3, D4, D7 `DebugClient.reset`) | dev-perf |
| P3 | NFR-17/NFR-18 not traced anywhere | perf §9 | add CI checks: "every Must FR has a test" trace script over the LLD test tables, and an import-direction / no-codegen check | dev-perf |

**Ownership check:** after R2/A6 no file has two owners. `app.dart` (perf) mounts trading's `OrderOutcomeListener` and
`AlertBannerHost`; `market_server.dart` (realtime) calls dev-ai's `mountAiApi`; `features/more/` is split by subfolder
(perf: `more_screen`, overlay; realtime: `socket_lab/`, `debug_clock/`). **JSON check:** wire fields in trading/ai match
realtime §4.2/§5 (`cond`, `clientKey`, `version`, `l/ch/oi/d/iv/dl`, `asOf`, `ex`); snapshot quotes reuse `Quote.toJson`.

## 4. Coverage check (PRD v1.1 FR/NFR and TRD TR → LLD)

Automated scan of the four LLDs (IDs and ranges) for 96 FRs, 18 NFRs and 26 TRs. Before edits the gaps were **FR-83, FR-110,
NFR-17, NFR-18** (fixed by T8, R5, P3) and FR-28 (Could, deferred by D13). Ownership summary:

| Area | FR / NFR / TR | LLD |
|---|---|---|
| Instruments, clock, phases, settlement, square-off, T+1, alerts engine | FR-6, 7, 14 (data), 24, 29a, 29c, 37 (server), 44, 46, 49, 50, 51, 54, 116, 120…124; TR-1…5, 7, 9…11, 20, 22, 25, 26 | realtime |
| Freshness, socket, resync, keep-alive | FR-84, 85, 90…95; NFR-7, 10, 11; TR-6 (function) | realtime (+ trading banner FR-90) |
| Watchlist, stock page, chain UI, ticket, risk notice, portfolio, alerts UI, haptics, theme | FR-1…5, 10…13, 20…27, 29, 29b, 30…43, 45, 47, 48, 52, 53, 55, 83, 100…102, 113, 126; NFR-5, 8, 9, 12, 13; TR-6 (send-time), 8, 19, 21 | trading |
| Chat, cards, NDJSON, payoff, builder | FR-60…67, 70…73; TR-17, 18 | ai |
| Startup, cache, lazy tabs, visibility, observability, perf runs, More, reset | FR-80…82, 86, 87, 112, 114, 125; NFR-1…4, 6, 14…18; TR-12…16, 23, 24 | perf |

## 5. Verdict

The four LLDs agree on architecture and wire format; the remaining issues are naming and four missing additive APIs. Once
R1–R6, T1–T8, A1–A6 and P1–P3 land, the LLD set is **ready for stories** (scrum master can slice by HLD §10.3).

## 6. CR-1 impact (architect, 2026-11-07; HLD v2.0, ADR-0009…0021)

**Verdict: yes, refactor before wave 1 resumes.** Wave 0/1 code is still small (~5 k lines in `stock_pulse/lib`). Every
remaining wave-1 story (S-8, S-9, S-10a/b, S-14, S-17, S-18, S-22) would otherwise be written in the v1.1 shape and moved
again. So a short refactor wave **W1R** runs now; wave 1 resumes on the v2.0 structure.

**Stories in flight:** S-7 (dev-realtime, server) and S-21 (dev-ai, server) finish first, as CR-1 says, and include their
file splits. **S-13** (dev-perf, `AppShell` + route observer) **stops**: go_router replaces `AppShell`; the observer part
continues inside R-4. Stories in `review` (S-5, S-6, S-11, S-12, S-15, S-16, S-19, S-20) are judged on v1.1 rules and
closed; their code is reshaped by the R stories, not reopened. S-14 (CI checks) folds into R-0. S-40 loses
"delete `core/providers.dart`".

### 6.1 Order and why

| Step | Story | Owner | Size | Runs | Why this order |
|---|---|---|---|---|---|
| 1 | **R-0** tooling + repo-wide sweep | dev-perf | S (1 d) | alone, others stopped | lints, imports and `dart fix` touch every file; one person, one pass, no conflicts |
| 2 | **R-1a** `Result`/`AppError` rename, delete `core/providers.dart`, feature DI files | dev-realtime | S (0.5 d) | alone | mechanical edits in other owners' files (11 importers, 155 `Ok`/`Err`/`*Failure` refs) |
| 3 | **R-1b** ∥ **R-2** ∥ **R-3** ∥ **R-4** | each owner | see below | in parallel | after R-1a no file has two owners |
| 4 | W1R checkpoint: gates turn blocking (file length, deny-list, `--fatal-infos`, layer test, coverage 100 %) | manager | — | — | wave 1 resumes |
| later | **R-5** analytics + push + deep links (new capability, not refactor) | dev-perf | M (2 d) | wave 2 | needs the router (R-4); nothing in wave 1 calls it |

### 6.2 Per developer: what changes in wave 0/1 code

**dev-realtime — R-1a (S) + R-1b (L, ≈ 3 d). Total L, still the critical path.**
| Area | Change |
|---|---|
| `core/error/` | `Ok`→`Success`, `Err`→`Failure`, `Failure`→`AppError` (+ subclasses), `failure.dart`→`app_error.dart`, `valueOrNull` (ADR-0012), all call sites (R-1a) |
| `core/providers.dart` | delete; 11 importers import exact files (R-1a, ADR-0011) |
| `features/{market,options,orders,portfolio,alerts}/data/providers.dart` | → `features/<f>/<f>_providers.dart` at feature root, typed as domain interfaces (R-1a) |
| repositories | `MarketRepository`, `ChainRepository`, `OrderRepository`, `PortfolioRepository`, `AlertsRepository` become `abstract interface class` in `domain/`; classes renamed `Live*Repository` in `data/`; `liveQuoteProvider` → `features/market/application/live_quote_provider.dart` |
| `core/network/`, `core/market_time/` | split into `domain/ data/ application/` + `<module>_providers.dart` (ADR-0010 table); `debugClientProvider` into `network_providers.dart` |
| file length | `market_socket.dart` 431 → socket + frame decoder + subscription book; server `market_engine.dart` 542, `ws_gateway.dart` 509 (inside S-7), `instruments.dart` 480 (static table → `instrument_table.dart`), tests `protocol_v2_test.dart` 414, `market_test.dart` 348 split by group |
| comments | drop `// §10.2`, `// S-1 stub`, `// TODO(dev-realtime S-10a)` prose; keep why-comments |
| coverage | `core/network`, `core/market_time`, `core/error`, the five features' `domain/` + `data/`, `option_math/pricing.dart`, `market_server/lib` → 100 % |
| LLD | `realtime.md`: layer split, DI files, file list ≤ 300 lines, `Success`/`Failure` everywhere |

**dev-trading — R-2 (L, ≈ 3.5 d).**
| Area | Change |
|---|---|
| controllers | `watchlist_controller`, `stock_detail_controller`, `portfolio_controller` → `features/<f>/application/`; `StockDetailState`, `PortfolioState`, watchlist state into their own `*_state.dart`; widgets keep only visual state |
| `core/navigation/` | deleted: args → `orders/domain`, `options/domain` (+ `toQuery/fromQuery`), `alerts/domain`; `InstrumentId` → `market/domain`; openers → `market_routes.dart`, `options_routes.dart`, `orders_routes.dart`, `alerts_routes.dart`, `portfolio_routes.dart` over go_router (route list consumed by R-4); `chain_target.dart` removed |
| snackbars | build `core/feedback/` (controller, message, host; `SpSnack` folded in); `order_sheet.dart` (2 calls), `portfolio_screen.dart`, `order_update_listener.dart` → controller `show(...)` calls with keys |
| strings, icons | build `core/l10n/` (interfaces, `en` tables, delegate, `stringsProvider`, `plural`) and `core/assets/` (`AppIcons`, `AppImages`); move every literal and `Icons.` in market/portfolio/core widgets |
| `core/platform/` | haptics → `domain/` (`Haptics`, `HapticDedupe`) + `data/` (`MethodChannelHaptics`, `NoopHaptics`) + `platform_providers.dart` |
| file length | `candle_chart.dart` 463 → pure `candle_geometry.dart` + painter + gesture/crosshair layer; `stock_detail_screen.dart` 425 → scaffold + `widgets/` sections (header, range bar, stats, actions) |
| coverage | own files to 100 % (controllers by `ProviderContainer.test`, widgets by widget tests) |
| LLD | `trading.md`: layers, routes table, feedback keys (`<feature>.<reason>[.<id>]`), strings areas |
| not refactor | CR-1.0 charts like Kite and CR-1.0b picker arrive as new stories from PRD v1.4 / design |

**dev-ai — R-3 (M, ≈ 1.5 d), after S-21.**
| Area | Change |
|---|---|
| `features/strategy/` | `StrategyDraftRepository` (in-memory state) → `application/strategy_draft_controller.dart` (`Notifier<StrategyDraft>`, `addLeg`, `clear`, `load`) + `strategy_draft_state.dart`; `open_strategy_builder.dart` → `presentation/strategy_routes.dart` (`/strategy`) |
| `features/ai_chat/` (S-19/S-20/S-21 code) | `AiRepository` interface in `domain/`, `LiveAiRepository` in `data/`, `ai_chat_providers.dart`; chat controller (S-32) will be born in `application/` |
| `core/network/api_client_lines.dart` | path move to `core/network/data/` (owner unchanged) |
| file length | server `answer_builder.dart` 383, `card_json.dart` 364 (split per card type), `answer_builder_test.dart` 405 |
| strings | `AiStrings` area (chat, cards, builder) |
| coverage | strategy, ai_chat, `option_math/payoff.dart`, server `ai/` → 100 % |
| LLD | `ai.md`: v2.0 §10.2 C7 names, layers, routes |

**dev-perf — R-0 (S, 1 d) + R-4 (L, ≈ 3 d); R-5 (M) in wave 2.**
| Area | Change |
|---|---|
| R-0 tooling | `pubspec.yaml` + `go_router ^18.1.2`, `flutter_localizations`; `analysis_rules.yaml` + 3 `analysis_options.yaml` (ADR-0021); `dart fix --apply` per package (package imports, const, finals); `tool/ci/file_length_check.dart`, `tool/ci/deny_list.sh`, `tool/ci/coverage_check.dart` (+ tests), `test/architecture/layer_rules_test.dart` (report-only until W1R exit) |
| R-4 router | `app/router/` (`goRouterProvider`, `AppShellScaffold`, composition of feature route lists), `app.dart` → `MaterialApp.router` with `FeedbackHost` and `AppStringsDelegate`; `rootNavigatorKey` moves here |
| `core/lifecycle/` | → `core/visibility/` (domain `ScreenId`, `CoveredState`; application `selectedTabProvider`, `coveredStateProvider`, `screenVisibleProvider`; presentation `VisibilityRouteObserver`). `app_shell.dart` and `AppShellController.select` deleted (S-13 superseded); observer ignores the shell page |
| `lib/` root | `bootstrap.dart`, `app.dart`, `app/*` → `lib/app/` (composition root); `main.dart` one line |
| `core/storage/`, `core/observability/` | layered per ADR-0010 + `storage_providers.dart`, `observability_providers.dart`; `LocalPrefsData` + `analyticsConsent`, `localeOverride` |
| `features/socket_lab/` | → `features/more/` (`application/socket_lab_controller.dart`, screen snack → feedback), routes `/more/socket-lab` |
| tests | `test/helpers/sp_app.dart` builds `MaterialApp.router` with a test router; `test/core/lifecycle/*` → `test/core/visibility/*` |
| R-5 (wave 2) | `core/analytics/` (ADR-0017), `core/push/` + `app/push_link_handler.dart`, `deep_link.dart`, Android/iOS deep-link placeholders and `docs/deeplinks/` templates (ADR-0016) |
| LLD | `perf.md`: router, visibility with go_router, CI gates, R-5 |

### 6.3 Exit of W1R
`flutter analyze --fatal-infos` and `dart analyze --fatal-infos` clean; `file_length_check` clean; deny-list clean; layer
test green; coverage 100 % in all three packages; `flutter test` / `dart test` green; four LLDs updated to HLD v2.0 and
re-reviewed by the architect (this file, new §7). Then the scrum master re-cuts wave 1 stories on the v2.0 file lists.

### 6.4 `features/chart/` file owners (HLD v2.1 D14–D16; confirms stories v2.0 cr1.md §2 with the changes marked ★)

Four layers like every feature (ADR-0009/0010). One owner per file; a story never edits another owner's file — it asks.

| Path under `stock_pulse/lib/features/chart/` | Owner | Stories |
|---|---|---|
| `domain/indicators/**` (`study_kind`, `study_spec`, `study_series`, `indicator`, `sma`, `ema`, `vwap`, `rsi`, `bollinger`, `macd`, `study_catalog`) | dev-ai | S-52, S-70 |
| ★ `domain/fib_levels.dart` | dev-ai | S-52 (stub), S-71 |
| `domain/{chart_layout,drawing,chart_range,drawing_geometry,tick_snap}.dart` | dev-trading | S-53, S-55 |
| `domain/chart_store.dart` (interface), `data/**`, `chart_providers.dart` | dev-realtime | S-56 |
| `application/studies/**` | dev-ai | S-52 (stub), S-54 |
| `application/{chart_controller,chart_state}.dart`, `application/drawings/**` | dev-trading | S-53, S-55, S-72 |
| `presentation/studies/**` | dev-ai | S-52 (stubs), S-54 |
| ★ `presentation/drawings/fib_painter.dart` | dev-ai | S-52 (stub), S-71 |
| `presentation/**` else (`chart_view`, `candle_chart`, `candle_painter`, `candle_geometry`, `crosshair_layer`, `chart_toolbar`, `readout_row`, menus, `drawings/**` except `fib_painter`, `fullscreen/**`, `chart_settings_sheet`) | dev-trading | S-53, S-55, S-57, S-58, S-72, S-73 |

Rules and contracts:
- **D15 maths location.** Indicators stay in `domain/indicators/` (pure Dart; the layer test forbids Flutter except
  `foundation`, riverpod, `http`, `dart:io`). Not `packages/option_math` (ADR-0007 scopes it to option pricing and payoff
  shared with the server) and not a new package: the server and AI answers compute no indicators. Indicators take
  `List<Candle>` from `market/domain` (domain → other domain, allowed).
- **Stubs (S-52, dev-ai):** `StudyOverlayLayer`, `StudyPaneStack`, `StudyChipRow`, `showStudiesSheet`,
  `studiesControllerProvider` (empty list), ★ `fibLevels(a, b) → const []`, ★ `FibPainter.paint(...)` no-op and
  ★ `const bool fibToolReady = false` in `fib_levels.dart`. dev-trading mounts them and never edits them.
- ★ **S-71 → dev-ai (D16).** Fibonacci is a two-anchor drawing, the same as a trend line. **S-55 (dev-trading)** adds
  `DrawingKind.fibRetracement` to `Drawing` (+ JSON), lets `drawings_controller` place / drag / save / limit-count every
  two-anchor kind the same way, makes `drawing_painter` delegate that kind to `FibPainter`, and shows the toolbar's Fib
  tool only when `fibToolReady`. **S-71 (dev-ai)** files become only `domain/fib_levels.dart`,
  `presentation/drawings/fib_painter.dart` and tests; it flips `fibToolReady` to true. S-71 AC unchanged; dep S-55.
- **Strings:** `core/l10n/strings/{chart,studies}_strings.dart` + `locales/en/{chart,studies}_strings_en.dart` (ADR-0018
  naming, not `chart_en.dart`); `chart` area dev-trading, `studies` area dev-ai (also Fib labels). dev-trading adds both
  `AppStrings` getters in S-53 against the `studies` interface dev-ai ships in S-52. Icons: ask dev-trading (`AppIcons`).
- **Other features** use the chart through `features/chart/presentation/` only (ADR-0009 presentation → presentation):
  dev-ai's `MiniChartCardBody` imports `CandleChart` (`interactive: false`, `showVolume: false`, kept from S-18).
- Coverage: `features/chart/**` is in the 100 % `stock_pulse` gate (NFR-19) like every feature.
