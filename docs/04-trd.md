# 04 · TRD: StockPulse v2

Owner: architect · Status: **v2.0, CR-1** (TR-27…TR-39, §1 and §1.1 updated, §8 CI gates) · Input: `09-change-request-1.md`, `02-prd.md` v1.1, `03-ux-spec.md` v1.3, `03b-design-system.md` v1.4,
`team/reviews/prd-architect.md`, the four proposals in `team/proposals/` · Next: `05-hld.md`, LLDs in `06-lld/`
Decisions with real alternatives are recorded as ADRs in `docs/adr/` (0001–0021; CR-1 decisions are 0009–0021).

## 1. Stack

| Layer | Choice | Version | Note |
|---|---|---|---|
| App | Flutter, Dart 3 | SDK `^3.13.7` (v1 pin) | Phone portrait, Android + iOS; macOS for local dev only |
| State | `flutter_riverpod` 3, **manual providers** | `^3.4.3` (v1) | No `riverpod_generator`, no `freezed` (NFR-18). Controllers in each feature's `application/` layer (ADR-0009) |
| Models | Hand-written immutable classes, `==`/`hashCode`, `copyWith`, `fromJson`/`toJson` | — | Sealed classes for unions (`SocketMessage`, `PlaceOutcome`, `AiEvent`, `AiCard`) |
| Transport | `web_socket_channel` (one socket), `http` (REST and AI NDJSON) | v1 | `http` ≥ 1.3 gives `AbortableRequest` for AI cancel |
| Navigation | **`go_router`**, `StatefulShellRoute.indexedStack` (5 lazy branches), hand-written typed route helpers | `^18.1.2` | v2.0: **reverses** v1.0 "no go_router" because CR-1.15 puts deep links and push taps in scope (ADR-0015). No `go_router_builder` |
| Localisation | Hand-written `AppStrings` per locale + `flutter_localizations` (SDK) + `intl` plurals | SDK | Not gen_l10n: it generates code (ADR-0018) |
| Lints | `flutter_lints` / `lints` + shared `analysis_rules.yaml` (strict modes, explicit rules) | — | ADR-0021 |
| Server | Dart `shelf`, `shelf_router`, `shelf_web_socket` | v1 | One process, in-memory state |
| Shared maths | `packages/option_math` (pure Dart, path dependency of app and server) | new | ADR-0007 |
| Platform | One `MethodChannel('stockpulse/haptics')` (Kotlin, Swift) | — | FR-100…102 |

### 1.1 New dependencies (each justified; nothing else may be added without an ADR)

| Package | Where | Why | Rejected alternatives |
|---|---|---|---|
| `path_provider` | app | Only way to get the app-support directory for `snapshot.json` and `prefs.json` (ADR-0005). Flutter team package, no codegen. Called inside the un-awaited cache future | `shared_preferences` (async init invites an `await` in `main`, Android rewrites one XML), `sqflite`/`drift`/`hive` (native lib, schema, codegen for one document) |
| `option_math` (local path) | app + server | One implementation of Black-Scholes and payoff so chain, greeks sheet, AI card and builder agree (ADR-0007) | Copy the maths twice; server-only payoff endpoint |
| `integration_test`, `flutter_driver` (SDK) | app dev | Frame timing runs for NFR-4/5/6 (`traceAction`, `TimelineSummary`) | — |
| `go_router` ^18.1.2 (v2.0) | app | URL routing for deep links and push taps; `StatefulShellRoute` gives lazy, state-keeping tabs (TR-13) for free; Flutter team package, no codegen, deps are `meta`, `collection`, `logging` (ADR-0015) | own `RouterDelegate` (we would write go_router badly); `auto_route` (codegen); hand-parsing links into `Navigator` calls |
| `flutter_localizations` (SDK, v2.0) | app | Material/Cupertino widget strings and date pickers in each supported locale; needed the day a second locale lands (ADR-0018) | — |
| `coverage` (v2.0) | `market_server`, `option_math` dev | `format_coverage` turns `dart test --coverage` output into lcov for the gate (ADR-0020). The app uses `flutter test --coverage` and needs nothing | `test_cov_console` (reporting only) |

**Rejected:** `visibility_detector` (needs no package: the FR-63 50 % check is a small in-house `LiveWhenVisible` using the
`Scrollable` viewport rect, and the package cannot see hidden tabs or covered routes anyway, ADR-0004); `go_router` (v1.0 only,
reversed in v2.0); `firebase_messaging`, `firebase_analytics` and other vendor SDKs (placeholders only, ADR-0016/0017);
`very_good_analysis` (ADR-0021); gen_l10n / `intl_utils` (codegen, ADR-0018); `app_links` (built-in deep linking suffices);
`shared_preferences`; any vibration plugin (the channel is the JD point J9); protobuf/binary frames (codegen, unreadable in Socket Lab).
**Font:** platform default per 03b (no bundled font, protects NFR-2). Golden and text-scale tests (NFR-12) load a bundled
**test-only** font with `FontLoader` so goldens are stable; the app ships none.

## 2. Technical requirements

| TR | Requirement |
|---|---|
| TR-1 | One WebSocket per app with channels `quotes`, `chain`, `orders`, `alerts`; one per-session `seq` on every data frame (ADR-0001) |
| TR-2 | Every data frame carries frame-level `asOf` (server **wall** time); it confirms every subscribed value in that frame; exceptions listed in `ex` (ADR-0002) |
| TR-3 | Keep-alive `ka` frame every 1 s re-confirms unchanged subscriptions (worst healthy age ≈ 1.25 s, FR-95 ≤ 2 s) |
| TR-4 | Server `MarketClock` keeps **wall time** (asOf, staleness, keep-alive) and **market time** (phase, expiry, pricing, candles, order times) apart; debug jumps move market time only (ADR-0002) |
| TR-5 | Client `ServerClock`: `serverNow = deviceNow + offset`, offset from `welcome.serverTime`, refined by `pong` (lowest-RTT of last 5). Nothing is live before `welcome` |
| TR-6 | One pure `freshnessOf(...)` implements PRD §3.1 for every screen; Confirm calls it synchronously in the same turn as the POST |
| TR-7 | Chain = one `chain` subscription per (underlying, expiry), range = visible strikes ± 5, debounced 250 ms; max 2 chain subs per session; quote cap 100 |
| TR-8 | `OptionCell`/`ChainRow`/`Quote` equality **excludes** `asOf`; freshness comes from the shared check, so a keep-alive never rebuilds a cell (ADR-0003) |
| TR-9 | Resync: quotes and chain via socket `resync` op (one ordered stream); orders, positions, funds, alerts via REST, merged by `version` / `alertId` |
| TR-10 | `order` frames echo `clientKey` (the idempotency key); `GET /api/v1/orders?key=` resolves a lost ack; REST ack and frame merge by `version` |
| TR-11 | Ref-counted subscriptions: mode = max, `throttleMs` = min of holders; socket re-sends when a holder leaves; 300 ms linger before unsubscribe |
| TR-12 | `ScreenVisibility` (selected tab AND not covered by an opaque route) is the primary stream-lifecycle signal; Riverpod `TickerMode` pausing is a backup only (ADR-0004) |
| TR-13 | Lazy tabs: unvisited tabs are not built; visited tabs stay built (scroll kept) |
| TR-14 | `main()` awaits nothing: crash hook, start cache read future, `runApp` in one turn (NFR-1) |
| TR-15 | Cache = `snapshot.json` (schemaVersion, savedAt, watchlist quotes, positions, holdings, summary); atomic tmp+rename; saved on `onHide`, every 30 s **only if structurally dirty**, after a resync **only when live**; > 7 days / wrong schema / corrupt → delete + one log (ADR-0005) |
| TR-16 | Local prefs = `prefs.json` (risk-notice ack, haptics on/off, alert seen-set ≤ 500 ids, last chain underlying), same store rules, read lazily |
| TR-17 | AI = `POST /api/v1/ai/ask` → NDJSON events `start`, `card`, `delta`, `done`, `error`; cancel = abort request; cards carry ids and a first-paint snapshot with `asOf`; never on the socket `seq` (ADR-0006) |
| TR-18 | `option_math`: `pricing.dart` (owner dev-realtime) and `payoff.dart` (owner dev-ai); exact kink-based `payoffSummary`; today line uses **market time** (ADR-0007) |
| TR-19 | Theme via `SpColors` and `SpTypography` `ThemeExtension`s; `MarketColors` deleted; no `Colors.` outside `core/theme` (CI grep) (ADR-0008) |
| TR-20 | Positions keyed (symbol, product); holdings a separate book; funds debit/credit on fill; settlement and MIS square-off from one `ClockScheduler` |
| TR-21 | Haptics fire only from the app-level `OrderOutcomeListener`, once per (orderId, status) via `HapticDedupe` |
| TR-22 | Test hooks FR-120…126 land first (M-A): injectable clocks, per-symbol freeze, REST faults, `/debug/subscriptions`, Timeline marks, fake haptics |
| TR-23 | Per-frame perf marks and `PaintProbe` compiled in only with `const kPerfProbe = bool.fromEnvironment('PERF_PROBE')` |
| TR-24 | `CrashReporter` interface wired to `FlutterError.onError` and `PlatformDispatcher.instance.onError` before `runApp` |
| TR-25 | Instrument metadata (`kind`, `lotSize`, `tickSize`, `bandLow`, `bandHigh`, `strikeStep`, `expiry`, `strike`, `right`) is the only source of trading numbers (NFR-9); option id `NIFTY-261110-24500-CE` |
| TR-26 | Option pricing: Black-Scholes from a parametric smile with OU-drifting ATM IV; no IV solving; T floored at 1 min; settle at intrinsic |
| TR-27 | Every feature has `domain/`, `data/`, `application/`, `presentation/` as needed; controllers and their immutable state live in `application/`; presentation is UI only (ADR-0009) |
| TR-28 | Layer import rules (ADR-0009 table, HLD §4.2) and "core never imports features/app" are enforced by `test/architecture/layer_rules_test.dart` (parses `package:stock_pulse/...` imports); no `export` barrels and no `part` files in `lib/` (CI grep). Repository providers live in `features/<f>/<f>_providers.dart`; `core/providers.dart` is deleted (ADR-0011) |
| TR-29 | Package imports only (`always_use_package_imports` as error); the only relative imports are test → `test/helpers/` (ADR-0013) |
| TR-30 | No `.dart` file over 300 lines in any package; `tool/ci/file_length_check.dart` fails CI; allow-list empty (ADR-0014) |
| TR-31 | No generated code of any kind, including gen_l10n; CI greps for `part '`, `.g.dart`, `.freezed.dart`, `@riverpod`, `build_runner`, `generate: true` (NFR-18, ADR-0018) |
| TR-32 | Navigation through one `GoRouter` (`goRouterProvider`); 5 tabs = `StatefulShellRoute.indexedStack` with `preload: false`; route names = `ScreenId.x.name`; route paths only in `*_routes.dart` (CI grep); `screenVisibleProvider` contract unchanged (ADR-0015) |
| TR-33 | Deep links `stockpulse://app/<path>` and `https://stockpulse.example.com/<path>` map to router paths through `normaliseLink` + `DeepLinkPolicy`; no link can place/modify/cancel an order or carry a price; push taps take the same path via `PushService` (no-op in v2.0) and `PushLinkHandler` (ADR-0016) |
| TR-34 | Analytics only through `AnalyticsService.log` from application code and router observers; events from the `Events` catalogue; consent-gated; sinks never block or throw to callers; no PII in params (ADR-0017) |
| TR-35 | FR/NFR traceability lives in test names and LLD tables, not in production comments (ADR-0014 rule 1) |
| TR-36 | All user-visible text from `AppStrings`; images from `AppImages`; icons from `AppIcons`; CI greps reject `Icons.`, `'assets/` and `Text('literal')` elsewhere (ADR-0018) |
| TR-37 | One snackbar at a time: only `FeedbackHost` calls `showSnackBar`; same-key messages are ignored, different keys replace (CI grep, widget test) (ADR-0019) |
| TR-38 | 100 % line coverage of `stock_pulse/lib`, `option_math/lib`, `market_server/lib` with exclusions E1–E4 only, measured by `tool/ci/coverage_check.dart` over lcov plus an all-imports test; blocking from W1R exit; TDD per build brief (ADR-0020) |
| TR-39 | `flutter analyze --fatal-infos` / `dart analyze --fatal-infos` with the shared `analysis_rules.yaml` and `dart format --set-exit-if-changed` pass in CI (ADR-0021) |

## 3. Performance budgets and how they are met

| NFR | Budget | How it is met | Measured by |
|---|---|---|---|
| NFR-1 | First frame p50 ≤ 800 ms | TR-14; no bundled font; lazy tabs (TR-13); socket opened on first build, not before | `tool/perf/startup.sh`, `--trace-startup`, 10 cold runs |
| NFR-2 | Cache painted p50 ≤ 1.0 s | Snapshot ≤ 64 KB, decode on UI isolate (< 2 ms gate, `Isolate.run` only if > 4 ms) | `cache_painted` mark |
| NFR-3 | First live tick p50 ≤ 2.0 s | Subscribe ack sends current values at once; welcome handler does no heavy work | `first_live_tick_painted` |
| NFR-4 | 50-row watchlist 4 Hz, p90 < 16 ms, ≤ 1 % missed | Rows `select` their quote; `itemExtent`; `RepaintBoundary` per row; no `Opacity`/`saveLayer`; tint computed from tick time, no timers | `integration_test/perf/watchlist_perf_test.dart`, 5 runs |
| NFR-5 | 41-strike chain, rebuilds ≤ changed cells | TR-7, TR-8; one `Map<int, ChainRow>` with new instances only for changed rows; OI bar selects a quantised width bucket; stale flags emitted only on flips | `chain_perf_test.dart` + build-counter test |
| NFR-6 | frame → paint p90 ≤ 50 ms | No vsync batching (one emit per socket frame at 250 ms flush is fine); JSON decode < 2 ms | `frame_received(seq)` → `price_painted(seq)` probe |
| NFR-14 | 0 subs in background ≤ 2 s; off-screen cards ≤ 1 s | v1 `pause()`; TR-11 linger 300 ms + 200 ms visibility check ≤ 0.6 s | `GET /debug/subscriptions` (FR-124) |
| NFR-16 | RSS ≤ 250 MB, heap growth ≤ 10 MB / 10 min | Socket Lab ring 500 frames, chat ≤ 50 answers, candles ≤ 2000, no per-tick allocations kept | DevTools snapshots |

Wire budget (dev-realtime §3): chain ≈ 7.5 KB/s, watchlist ≈ 15 KB/s, worst both ≈ 23 KB/s, ≤ 9 frames/s; with TR-12 the
covered watchlist is unsubscribed, so the chain screen costs ≈ 8 KB/s. Reference devices per PRD §5.1 (Pixel 6a at 60 Hz;
emulators never produce NFR numbers).

## 4. Security and privacy

| Topic | Rule |
|---|---|
| Auth | Single demo token (`Bearer demo-token` on REST, `?token=` on the socket, checked before upgrade). Documented as a demo stand-in for OAuth session tokens; never logged by the app |
| Transport | `http`/`ws` only to a local/LAN dev server. Android cleartext allowed by a debug-only `network_security_config` for the configured host; release builds would require `https`/`wss` |
| Debug endpoints | `/debug/*` (clock, freeze, faults, reset, subscriptions) mounted only when the server runs with `--debug` (default in demo mode, off with `--clock=real` unless passed) |
| Order safety | Chat has no order path: `ai_chat` imports no order/alert repository (architecture test); actions only open prefilled screens (FR-64) |
| Local data | `snapshot.json`/`prefs.json` hold simulated prices and positions only; no PII exists. Stored in app-support dir (not backed-up docs dir), deleted by Reset (FR-112) |
| Logging | `CrashReporter.log` carries event names and small maps; no tokens, no request bodies. Socket Lab exists only in More > Developer |
| Disclosure | Every price, card and order sheet labelled simulated; F&O risk notice (FR-113) |

## 5. Environments

| Env | Server | App | Use |
|---|---|---|---|
| Unit | none | `FakeClock`, fake repositories | pure logic: freshness, calendar, pricing, payoff, validator, merge |
| Widget | none | provider overrides, `FakeHaptics`, fake socket | screens, rebuild counters, goldens at 1.0×/2.0× |
| Integration (CI, macOS) | in-process `TestServer` (v1 dev dependency `market_server`) with `FakeMarketClock` | real repositories | resync, sub counts, faults, NFR-8, NFR-10, NFR-11 |
| Demo / dev | `dart run market_server --clock=demo --debug`, port 8080 | `--dart-define=SERVER_HOST=<LAN IP>` | manual QA, demos |
| Profile perf | same server on LAN | `flutter run --profile` (+ `PERF_PROBE=true` for NFR-6 only) on the reference device | NFR-1…6, NFR-16 |

## 6. Test hooks (Must, first in M-A; QA depends on them)

| FR | Hook | Owner |
|---|---|---|
| FR-120 | `MarketClock` (server: `wallNow`, `marketNow`, `jumpTo`, `delay`) and `Clock` (client) injected everywhere; fakes in tests | dev-realtime |
| FR-121 | `POST /debug/freeze?symbol=X&seconds=N` (removes X from frames and `ka`, lists it in `ex`) | dev-realtime |
| FR-122 | `POST /debug/faults` {delayMs, status, dropAckAfterStore, path, count} shelf middleware | dev-realtime |
| FR-123 | `POST /debug/clock` {time}, `GET /api/v1/clock` | dev-realtime |
| FR-124 | `GET /debug/subscriptions` counts per session and channel, plus `activeAiAnswers` | dev-realtime (+ dev-ai counter) |
| FR-125 | Marks `main_start`, `cache_read_done`, `cache_painted`, `socket_welcome`, `first_live_tick_painted`, `frame_received(seq)`, `price_painted(seq)`, `ai_first_card_painted`, `ai_stream_done` | dev-perf |
| FR-126 | `FakeHaptics` override + `TestDefaultBinaryMessengerBinding` channel mock | dev-trading |

## 7. Traceability (FR/NFR → TR)

| FR / NFR | TR |
|---|---|
| FR-1, FR-2, FR-5, NFR-4 | TR-1, TR-6, TR-8, TR-11, TR-19 |
| FR-6, FR-7, FR-33, FR-34, NFR-9 | TR-25 |
| FR-14, FR-37, FR-44, FR-46, FR-49, FR-111, FR-116 | TR-4, TR-20, TR-22 |
| FR-20…FR-26, FR-29a, FR-29c, NFR-5 | TR-7, TR-8, TR-26 |
| FR-27, FR-70…FR-73 | TR-18, TR-26 |
| FR-29, FR-29b, FR-64 | TR-16 (last underlying), HLD §9 openers |
| FR-31, FR-31a, FR-38, FR-38a, FR-92, NFR-8 | TR-6, TR-10 |
| FR-39, FR-39a, FR-41…FR-48 | TR-9, TR-20 |
| FR-50…FR-55, NFR-10 | TR-9, TR-16 |
| FR-60…FR-67 | TR-11, TR-17 |
| FR-80, FR-81, FR-87, NFR-2 | TR-14, TR-15 |
| FR-82, FR-86, NFR-14 | TR-12, TR-13, TR-11 |
| FR-83, FR-84, FR-85, NFR-11 | TR-1, TR-9 |
| FR-90…FR-95, NFR-7 | TR-2, TR-3, TR-5, TR-6 |
| FR-100…FR-102, FR-126 | TR-21 |
| FR-110, FR-112, FR-113, FR-114 | TR-15, TR-16, TR-23 |
| FR-120…FR-125, NFR-17 | TR-22, TR-23 |
| NFR-1, NFR-3, NFR-6 | TR-14, TR-23 |
| NFR-12, NFR-13 | TR-19 (+ test font, §1.1) |
| NFR-15 | TR-23, TR-24 |
| NFR-16 | §3 caps |
| NFR-18 | §1 stack, TR-31 |
| CR-1.1, CR-1.5, CR-1.8, CR-1.9 | TR-27, TR-28 |
| CR-1.3, CR-1.4 | TR-30, TR-35 |
| CR-1.6 | TR-29 |
| CR-1.7 | HLD §10.2 C1 (ADR-0012) |
| CR-1.2 | TR-37 |
| CR-1.10 | TR-39 (+ ADR-0021 practices table) |
| CR-1.11 | TR-31, TR-36 |
| CR-1.14, NFR-17 | TR-38 |
| CR-1.15 | TR-32, TR-33 |
| CR-1.16 | TR-34 |

## 8. CI gates (v2.0; owner dev-perf; order = cheapest first)

| # | Step | Command | Blocks from |
|---|---|---|---|
| 1 | Format | `dart format --output=none --set-exit-if-changed .` (each package) | R-0 |
| 2 | File length | `dart run tool/ci/file_length_check.dart` (TR-30) | W1R exit |
| 3 | Deny-list greps | `tool/ci/deny_list.sh`: codegen markers, `export` in `lib/`, `Colors.` outside `core/theme`, `Icons.`, `'assets/`, `Text('literal')`, `showSnackBar` outside `FeedbackHost`, route paths outside `*_routes.dart`, `print(` (TR-19, TR-28, TR-31, TR-32, TR-36, TR-37) | W1R exit |
| 4 | Analyze | `flutter analyze --fatal-infos` / `dart analyze --fatal-infos` (TR-29, TR-39) | W1R exit |
| 5 | Tests + layer rules | `flutter test --coverage`, `dart test --coverage=coverage` (includes `test/architecture/`, TR-28) | now |
| 6 | Coverage | `dart run tool/ci/coverage_check.dart coverage/lcov.info --lib lib --min 100` per package (TR-38) | W1R exit |
| 7 | FR trace | every Must FR has a named test (P3, perf LLD) | W1R exit |
