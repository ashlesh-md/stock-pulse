# 06 · LLD: startup, lifecycle, storage, observability, perf harness (dev-perf)

Status: **v2.0** (R-4: go_router, visibility, composition root, storage layering; CR-2 structure rules) · Input: HLD v2.1 §4, ADR-0004, 0009, 0010, 0015, 0016, 0018, 0019, 0020, CR-2
ADR-0004, ADR-0005 · Owner: dev-perf · Step 2' in HLD §10.3 (parallel with dev-realtime step 2).

Rules that hold for every file below: manual Riverpod 3 providers; hand-written immutable classes with `==`/`hashCode`,
`copyWith`, `fromJson`/`toJson`; no code generation; one controller per screen; the only new package is `path_provider`
(TRD §1.1). Signatures from HLD §10.2 are cited **verbatim** and marked `// §10.2`.

**v1.1 changes (architect review, `06-lld/README.md` P1–P3, D3, D4, D7):**
- P1: `summary` removed from `snapshot.json` and `AppSnapshot`. The seed derives it with dev-trading's pure `PortfolioSummary.compute(positions, holdings, quotes)` (§4.2).
- P2: §11 now lists the approved v1.1 names: `MarketRepository.watchlistIds` / `setWatchlist` / `latestQuotes` / `seedFromCache`, `PortfolioRepository.current` → `PortfolioBook`, `DebugClient.reset`, and D4 route naming with `pushReplacement` for `stockDetail`.
- P3: CI checks 6–7 added for NFR-17 (every Must FR has a test row in an LLD test table) and NFR-18 (import direction, no codegen packages) (§9).

**v1.2 changes (S-41 moved from dev-realtime, architect-approved, HLD §4):**
- §7.1 added: debug clock screen and Socket Lab UI (FR-110, FR-111), moved from `realtime.md` §7.6. Files `features/more/{debug_clock,socket_lab}/**` added to §2; tests T27–T28 added to §10. dev-realtime keeps `DebugClient`, `MarketSocket.frames` and `/debug/*`.

## 1. Scope
- **FR:** FR-110, FR-111 (UI; v1.2), FR-80, FR-81 (seed + marks; stale maths is dev-realtime), FR-82, FR-85, FR-86, FR-87, FR-102 (toggle storage + Settings row), FR-112 (local wipe + More row), FR-114, FR-125.
- **NFR:** NFR-1, NFR-2, NFR-3, NFR-4/5/6 (harness), NFR-14 (lifecycle side), NFR-15, NFR-16 (method).
- **TR:** TR-11 (linger contract, implemented by dev-realtime), TR-12, TR-13, TR-14, TR-15, TR-16, TR-22 (FR-125 part), TR-23, TR-24.
- **Not mine:** `freshnessOf`, `MarketSocket` internals, linger implementation (dev-realtime); screens inside tabs, openers (dev-trading); `LiveWhenVisible` (dev-ai). Since v1.2 the Socket Lab and debug clock UI are mine (§7.1); their APIs are dev-realtime's.

## 2. Files (v2.0)
```
lib/main.dart                                   void main() => bootstrap();
lib/app/bootstrap.dart                          bootstrap(), appScope(): nothing awaited before runApp
lib/app/app.dart                                MaterialApp.router, AppStringsDelegate + Global*Localizations, builder hosts
lib/app/app_lifecycle_host.dart                 hidden → socket pause + snapshot save; shown → resume
lib/app/di/app_providers.dart                   goRouterProvider, snapshotSchedulerProvider (joins core storage to 3 features)
lib/app/router/app_route.dart                   sealed AppRoute (+ fromUri), one final subclass per screen
lib/app/router/navigation.dart                  context.goTo / context.pushTo (stock page replaces a stock page)
lib/app/router/app_router.dart                  buildAppRouter: StatefulShellRoute.indexedStack, 5 lazy branches, root routes
lib/app/router/app_shell_scaffold.dart          NavigationBar; only writer of selectedTabProvider (post-frame)
lib/app/router/widgets/tab_placeholder.dart     Options / AI tab roots until S-27 / S-32
lib/core/visibility/domain/{screen_id,covered_state}.dart       ScreenId, kTabs, kShellPageName, CoveredState
lib/core/visibility/application/{selected_tab,covered_state_notifier,screen_visibility}.dart
lib/core/visibility/presentation/visibility_route_observer.dart
lib/core/visibility/di/visibility_providers.dart                selectedTabProvider, coveredStateProvider, screenVisibleProvider
lib/core/storage/domain/{app_snapshot,snapshot_store,local_prefs}.dart
lib/core/storage/data/{atomic_json_file,file_snapshot_store,file_local_prefs}.dart
lib/core/storage/application/snapshot_scheduler.dart
lib/core/storage/di/storage_providers.dart      snapshotProvider, snapshotStoreProvider, localPrefsProvider
lib/core/observability/domain/crash_reporter.dart
lib/core/observability/data/{debug_crash_reporter,perf_marks,paint_probe}.dart
lib/core/observability/di/observability_providers.dart          crashReporterProvider
lib/core/l10n/strings/{shell,more}_strings.dart + locales/en/{shell,more}_strings_en.dart
lib/features/more/domain/chaos.dart             Chaos → typed Endpoint
lib/features/more/application/{socket_lab_controller,socket_lab_state,chaos_text}.dart
lib/features/more/di/more_providers.dart        socketLabControllerProvider
lib/features/more/presentation/screens/{more_screen,socket_lab_screen}.dart
lib/features/more/presentation/widgets/{frame_tile,chaos_buttons,socket_status_text}.dart
```
Routes (all in `app/router`, CR-2): `/` → `/watchlist`; branches `/watchlist`, `/options?u&e`, `/ai`, `/portfolio?tab`, `/more`;
root `/stock/:id`, `/strategy`, `/more/socket-lab`. Unknown location → `/watchlist`. Other owners post new routes in thread `build`.

## 3. `main()` and bootstrap (TR-14, TR-24, NFR-1)
`bootstrap()` is synchronous and returns `void`. In order, in **one** event-loop turn:
1. `WidgetsFlutterBinding.ensureInitialized()`: needed before the `path_provider` channel call. `runApp` would call it anyway, so it adds no cost.
2. `PerfMarks.mark('main_start')`.
3. `final reporter = DebugCrashReporter(); installCrashHooks(reporter);` sets `FlutterError.onError` and `PlatformDispatcher.instance.onError` (returns `true`). No `runZonedGuarded`.
4. `final dir = getApplicationSupportDirectory();` returns a `Future<Directory>` and is **not awaited**.
5. `final snapshotFuture = FileSnapshotStore.readInitial(dir, reporter, const SystemClock());` returns a `Future<AppSnapshot?>` that never throws.
6. `final prefs = FileLocalPrefs(dir, reporter);` does no IO in the constructor; it loads on the first `localPrefsProvider` read (TR-16 "read lazily").
7. `runApp(ProviderScope(overrides: [crashReporterProvider.overrideWithValue(reporter), snapshotProvider.overrideWith((ref) => snapshotFuture), localPrefsProvider.overrideWith((ref) => prefs.load()), snapshotDirProvider.overrideWithValue(dir)], child: const StockPulseApp()))`.

Forbidden before `runApp`: any `await`, socket start, REST, font loading, `SharedPreferences`. The socket starts when
`marketSocketProvider` is first read during the first build (HLD §7). `snapshotProvider.future` resolves to `null` on: no file,
wrong schema, > 7 days, decode error. Each discard writes one `cache_discarded` log `{reason: missing_schema|old|corrupt, bytes}`
and deletes the file. A missing file is not logged. After the read, `PerfMarks.mark('cache_read_done')`.

## 4. Storage (TR-15, TR-16, ADR-0005)

### 4.1 `AtomicJsonFile` (shared by both files)
- `Future<Map<String, Object?>?> read()`: if `name.tmp` exists, delete it first (the last write was interrupted and the main file is intact); then read and `jsonDecode` the main file.
- `Future<void> write(Map<String, Object?> json)`: encode → `name.tmp` with `writeAsString(flush: true)` → `rename(name)`.
  **Single writer and coalescing:** a write while another is in flight stores the newest map as `pending`. When the current write ends, only the latest pending one is written. So 3 saves during one write give 2 disk writes, and the last state always wins.
- `Future<void> delete()`: waits for the in-flight write, drops `pending`, deletes both files.
- Location: `getApplicationSupportDirectory()`. This directory is not user-visible and is not in the iOS Documents backup (TRD §4).

### 4.2 `snapshot.json` schema v1
```json
{"schemaVersion":1,"savedAt":1762412400000,
 "watchlist":{"ids":["NIFTY","RELIANCE","HDFCBANK"],"quotes":[{"id":"RELIANCE","ltp":1432.5,"change":12.3,"changePct":0.87,"prevClose":1420.2,"asOf":1762412399750,"seq":0,"fromCache":true}]},
 "positions":[/* Position.toJson (dev-realtime) */],"holdings":[/* Holding.toJson (dev-realtime) */]}
```
```dart
@immutable class AppSnapshot {
  const AppSnapshot({required this.savedAt, required this.watchlistIds, required this.quotes,
    required this.positions, required this.holdings});
  final DateTime savedAt; final List<String> watchlistIds; final List<Quote> quotes;   // fromCache: true after decode
  final List<Position> positions; final List<Holding> holdings;   // no summary: derived on seed (v1.1, D3)
  factory AppSnapshot.fromJson(Map<String, Object?> j);  // throws FormatException on any bad field
  Map<String, Object?> toJson();                          // ==, hashCode, copyWith hand-written
}
const kSnapshotSchema = 1; const kSnapshotMaxAge = Duration(days: 7); const kSnapshotBudgetBytes = 64 * 1024;
```
- **Seeding:** `MarketRepository.seedFromCache(snapshot.quotes)` puts cached quotes in the repository. The portfolio seed computes its summary with `PortfolioSummary.compute(positions, holdings, quotes)` (dev-trading, pure); it is never stored, so the snapshot holds facts only.
- **Not cached:** the portfolio summary and funds (derived or REST-fresh), orders (FR-31a: the truth is `GET /orders`), chain prices, instrument trading metadata (NFR-9), chat (FR-66). `lastChainUnderlying` lives in prefs.
- **Decode:** `fromJson` forces `fromCache: true` on every quote, so `freshnessOf(fromCache: true, …)` is stale until a live frame. `seq` is written as 0, and dev-realtime's `_merge` lets the first live frame replace a `fromCache` value whatever its seq. Positions and holdings are display-only until REST replaces them.
- **Versioning:** there are no migrations. If `schemaVersion != kSnapshotSchema` the file is discarded. Any field change bumps the constant.
- **Age:** `Clock.now() − savedAt > 7 days` → discard. The device clock is good enough for a 7-day rule. `savedAt` is `serverClock.now()` when a welcome has been seen, otherwise `Clock.now()`.
- **Size:** encoding is on the UI isolate. If the encoded size is over `kSnapshotBudgetBytes` the file is still written, with one `cache_oversize {bytes}` log per run. The CI benchmark (§9) is the gate; move to `Isolate.run` only if decode is over 4 ms.

### 4.3 `SnapshotStore` and `SnapshotScheduler`
```dart
abstract interface class SnapshotStore { void markStructuralDirty(); Future<void> saveNow(AppSnapshot s); Future<void> clear(); } // §10.2
final snapshotProvider = FutureProvider<AppSnapshot?>(...);           // overridden in main()  // §10.2
final snapshotStoreProvider = Provider<SnapshotStore>((ref) => FileSnapshotStore(...));
final snapshotSchedulerProvider = Provider<SnapshotScheduler>(...);   // read once by AppShell
```
`SnapshotScheduler` decides **when** to save. It builds the `AppSnapshot` from the v1.1 read-only getters `MarketRepository.watchlistIds`,
`MarketRepository.latestQuotes(ids)` and `PortfolioRepository.current` (positions, holdings), never from screen controllers:
| Trigger | Saves when |
|---|---|
| `AppShell` `onHide` | `hasLiveData` (at least one REST load or live frame since start) |
| 30 s `Timer.periodic` (from `clockProvider`-driven `Timer`, started on `onShow`, cancelled on `onHide`) | dirty && `hasLiveData` |
| `OrderRepository.resyncCompleted` | `networkStatus == live` (ADR-0005) |
| `markStructuralDirty()` | sets the flag only. Callers: `MarketRepository.setWatchlist` (v1.1), position open/close/qty change, holdings change (repositories, dev-realtime). LTP ticks never set it |

`hasLiveData` stops an offline start from rewriting the old cache with a newer `savedAt` (which would extend the 7-day rule).
`clear()` deletes the file and resets the flags (FR-112).

### 4.4 `prefs.json` schema v1 and `LocalPrefs`
```json
{"schemaVersion":1,"riskNoticeAcked":false,"hapticsEnabled":true,"seenAlertIds":["A17","A18"],"lastChainUnderlying":"NIFTY"}
```
```dart
class LocalPrefsData { bool riskNoticeAcked; bool hapticsEnabled; Set<String> seenAlertIds; String? lastChainUnderlying; } // copyWith  // §10.2
abstract interface class LocalPrefs { LocalPrefsData get data;
  Future<void> update(LocalPrefsData Function(LocalPrefsData current) change); Future<void> clear(); } // §10.2
final localPrefsProvider = FutureProvider<LocalPrefs>(...);          // overridden in main(), read lazily  // §10.2
```
- Defaults: `false, true, {}, null`. A missing file → defaults, no log. Corrupt or wrong schema → defaults, one `prefs_discarded` log, file rewritten on the next `update`. There is no age rule, so the 7-day snapshot discard never resets the risk ack.
- `update` applies `change` to the in-memory data synchronously (`data` reflects it at once), then writes through `AtomicJsonFile`.
- `seenAlertIds` uses a `LinkedHashSet` (insertion order) capped at 500. On overflow the oldest are dropped in `update` before writing.
- `clear()` resets to defaults and deletes the file (FR-112).

## 5. Visibility with go_router (ADR-0004, ADR-0015)
- `screenVisibleProvider(id)` = `isScreenVisible(id, selectedTab, covered)`: a tab when selected and nothing opaque covers the
  shell; a routed screen when it is the top opaque route.
- `selectedTabProvider` mirrors `navigationShell.currentIndex`; `AppShellScaffold` writes it after the frame.
- `VisibilityRouteObserver` is in `GoRouter(observers:)` (root navigator). The shell page is named `kShellPageName` and never
  counts; a cold-start link with no shell under it counts its page. go_router changes pages during build, so a change seen in
  the build phase is published once, after the frame (Riverpod forbids provider writes during build).
- Re-tap of the current tab: `goBranch(i, initialLocation: true)`.

**Deviations (v2.0):** `snapshotSchedulerProvider` lives in `app/di/` (it joins storage to market, portfolio, orders; core may
not import features). `AppSnapshot` still imports market/portfolio domain types (3 layer-test hits); needs an architect call
(move the snapshot to `app/` or make `SnapshotStore` take JSON). `prefs.json` stays schema v1: `analyticsConsent` (default
true) and `localeOverride` (language tag) are optional keys, so old files keep the risk ack. Layer test: `di/*_providers.dart`
may import `application/` (controller providers, CR-2 rule 1); presentation may not import `*_data_providers.dart`.

## 6. Observability (TR-23, TR-24, FR-114, FR-125, NFR-15)
```dart
abstract interface class CrashReporter { void recordError(Object e, StackTrace s, {bool fatal = false, String? reason});
  void log(String event, [Map<String, Object?> data]); }                       // §10.2
final crashReporterProvider = Provider<CrashReporter>((ref) => throw UnimplementedError()); // overridden in bootstrap
void installCrashHooks(CrashReporter r);  // FlutterError.onError → recordError(fatal: false, reason: 'flutter'), then FlutterError.presentError in debug; PlatformDispatcher.onError → fatal: true
abstract final class PerfMarks { static void mark(String name, {int? seq}); }  // §10.2
abstract final class PaintProbe { static void mark(int seq); }                  // no-op unless kPerfProbe  // §10.2
const kPerfProbe = bool.fromEnvironment('PERF_PROBE');
```
- `DebugCrashReporter`: `debugPrint` in debug and profile, keeps a ring of 100 entries for the overlay; release builds keep only the ring. `FakeCrashReporter` (test): `errors`, `logs` lists. A real Crashlytics/Sentry reporter would just implement the interface; none is added.
- `PerfMarks.mark` uses `Timeline.instantSync(name, arguments: seq == null ? null : {'seq': seq})`. The startup marks `main_start`, `cache_read_done`, `cache_painted`, `socket_welcome`, `first_live_tick_painted` are **once-only**: later calls are ignored, the value is stored as `Timeline.now` in `StartupMarks`, and they are always compiled in. `frame_received`, `price_painted`, `ai_first_card_painted`, `ai_stream_done` return at once unless `kPerfProbe`.
- **Who calls each mark:** `main_start` and `cache_read_done` (me). `cache_painted`: the watchlist screen, in a post-frame callback when its state is seeded from cache and has ≥ 1 row (dev-trading). `socket_welcome`: `MarketSocket` welcome handler (dev-realtime). `first_live_tick_painted`: the watchlist screen, post-frame, when ≥ 1 row has `fromCache == false` (dev-trading). `frame_received(seq)`: `MarketSocket._onFrame` (dev-realtime). `price_painted` is set by `PaintProbe`. The `ai_*` marks are set by dev-ai.
- **PERF line:** when `first_live_tick_painted` is marked, or 10 s after `main_start`, `StartupMarks` prints one line (`!kReleaseMode`): `PERF {"marks":{"main_start":<us>,...},"probe":{...}}`. All values are `Timeline.now` µs.
- **PaintProbe (NFR-6):** compiled in only with `PERF_PROBE=true`; the probed id comes from `--dart-define=PERF_PROBE_ID=RELIANCE` (default `RELIANCE`). The tile or cell for that id calls `PaintProbe.mark(quote.seq)` in build when its seq changes. The recorder stores `seq → PlatformDispatcher.instance.frameData.frameNumber`. A `SchedulerBinding.addTimingsCallback` matches `FrameTiming.frameNumber` and computes latency = `rasterFinish` µs − `frame_received` µs for that seq (`PerfMarks` keeps the last 64). It also marks `price_painted(seq)`. Samples (bounded at 2000) go into the PERF line as p50/p90. Samples where the clocks disagree (negative latency) are counted as `invalid`. A run is void if `invalid > 1 %`.
- **Debug overlay (FR-114):** `PerfOverlay` is an `Overlay` entry above the app, built only when `!kReleaseMode` and the More toggle is on. The toggle is held in memory, not persisted. It shows `StartupMarks` deltas from `main_start` and a rolling 120-frame window of build/raster average and p90 plus a jank count from `addTimingsCallback`. It is wrapped in `RepaintBoundary` and repaints at most 2 Hz.

## 7. More screen (shell only)
`MoreController` (`Notifier<MoreState{bool hapticsEnabled, bool overlayOn, bool resetting, Failure? error}>`) is the one
controller. Rows follow UX §3.9: Alerts, Strategy builder and Risk notice call dev-trading/dev-ai openers. Haptics toggle →
`LocalPrefs.update` (FR-102). Reset (FR-112): the confirm dialog, then `DebugClient.reset()` (dev-realtime, v1.1), then
`SnapshotStore.clear()`, `LocalPrefs.clear()`, then invalidate the portfolio, watchlist and alerts controllers. It is disabled
offline with "Needs connection". Market clock and Socket Lab open the §7.1 routes (`RouteSettings` names `debugClock`, `socketLab`; opaque, no `ScreenId`, so they cover the shell). Overlay toggle (FR-114).

### 7.1 Debug clock and Socket Lab (v1.2, S-41; moved from realtime.md §7.6)
APIs used (dev-realtime, unchanged): `DebugClient.setClock` / `reset` (§10.2 v1.1), `MarketSocket.frames`, `marketClockProvider`, `ApiClient.send` for `/debug/drop-connections`, `/debug/freeze`, `/debug/skip-seq`. One controller per screen.
- **Debug clock screen** (`features/more/debug_clock/`) (`DebugClockController`, `NotifierProvider.autoDispose`, state `DebugClockState{clock, busy, error,
  pendingBackward}`): presets 09:14:50, 15:19:50, 15:29:50 of the current trading day, "Next day 09:00", and a time picker.
  `applyPreset(t)`: if `t >= marketNow` → `setClock(t)`; if `t < marketNow` → state `pendingBackward = t`, the screen shows a
  confirm dialog "Going back resets the demo account" (Cancel / Reset and go back); confirm → `reset(marketTime: t)` + local wipe (`SnapshotStore.clear()`, `LocalPrefs.clear()`, same path as More › Reset); cancel → nothing sent. A 409 from `setClock` (race with a server jump) opens the same confirm. While `clock.overridden`
  the shell shows the "Demo clock" chip (FR-111, data from `marketClockProvider`).
- **Socket Lab** (`features/more/socket_lab/`, FR-110, under More › Developer): v1 screen reads `MarketSocket.frames`; the controller keeps a ring buffer of
  the last **500** `SocketFrame`s (older dropped, NFR-16), buttons call `/debug/drop-connections`, `/debug/freeze`,
  `/debug/skip-seq` via `ApiClient.send`. Hidden in release builds.

## 8. Measurement (NFR-1…NFR-6, NFR-16; PRD §5.2, prd-qa §3)
Common setup: profile build, Pixel 6a on Android 15 at 60 Hz (Settings › Display › Smooth display off), unplugged, battery > 50 %,
server `dart run market_server --clock=demo --debug` on the same Wi-Fi, `--dart-define=SERVER_HOST=<LAN IP>`. Emulators,
simulators and macOS never produce NFR numbers. iPhone 13 is reported but does not gate.

| NFR | Command | Output | Pass |
|---|---|---|---|
| 1 | `tool/perf/startup.sh --mode cold --runs 10 -d <id>`: per run `adb shell pm clear <pkg>` + `am force-stop`, then `flutter run --profile --trace-startup -d <id> --dart-define=SERVER_HOST=…`; also logs `adb shell am start -W` `TotalTime` for information | `build/start_up_info.json` per run → `build/perf/startup-<sha>.csv` | `timeToFirstFrameMicros` p50 ≤ 800 ms, p90 ≤ 1.2 s |
| 2 | same, `--mode warm` (one priming run, then `force-stop` only, cache kept) | PERF line from `adb logcat -s flutter` joined with `engineEnterTimestampMicros` | `cache_painted − engineEnter` p50 ≤ 1.0 s |
| 3 | same runs as 2 | same | `first_live_tick_painted − engineEnter` p50 ≤ 2.0 s |
| 4 | `tool/perf/frames.sh watchlist -d <id> --runs 5` → `flutter drive --profile --driver=test_driver/perf_driver.dart --target=integration_test/perf/watchlist_perf_test.dart`; server load flag (§11), 50 rows at 4 Hz, `binding.traceAction` around a 20 s scripted fling | `build/perf/watchlist.timeline_summary.json` | median of 5: `90th_percentile_frame_build_time_millis` and `…_rasterizer_time_millis` < 16.7 (16.0 also reported); `(missed_frame_build_budget_count + missed_frame_rasterizer_budget_count) / frame_count ≤ 1 %` |
| 5 | `frames.sh chain`: 41 strikes, 4 Hz, scroll ±15 rows, tap Back to ATM, 20 s | `chain.timeline_summary.json` | as NFR-4; plus the widget build-counter test (CI) |
| 6 | `frames.sh probe --dart-define=PERF_PROBE=true`: `startup_probe_test.dart` idles on the watchlist for 60 s, 3 runs | `probe` in the PERF line | p90 ≤ 50 ms, `invalid ≤ 1 %` |
| info | `frames.sh chat`: scroll chat with 2 live cards, 5 runs | `chat.timeline_summary.json` | reported against the NFR-4 rule, not gating |
| 16 | manual: DevTools Memory, chain open, snapshot at 1 min and 10 min of ticking | screenshots in `docs/perf-results.md` | RSS ≤ 250 MB; heap(10) ≤ heap(1) + 10 MB |

- `startup.sh` exits non-zero if any run's `main_start − engineEnter` is outside 0–2 s (wrong clock or broken trace). `summarize.dart` (plain Dart, no packages) computes p50/p90/medians and appends a row to `docs/perf-results.md`: device, OS, build SHA, date, NFR, runs, p50, p90, median, pass.
- `perf_driver.dart` uses `integrationDriver(responseDataCallback:)` → `TimelineSummary.summarize(timeline).writeTimelineToFile(name, pretty: true)`.

## 9. CI checks (every PR, macOS runner)
1. `flutter analyze`, `flutter test`, `dart test` in `market_server` and `packages/option_math`.
2. `pubspec.yaml` deny-list grep: `shared_preferences|sqflite|drift|hive|isar|visibility_detector|freezed|riverpod_generator|build_runner` must not match.
3. `grep -rn "Timeline\." lib/ | grep -v lib/core/observability/` must be empty (all marks go through `PerfMarks`/`PaintProbe`, TR-23).
4. Cache benchmark (`test/core/storage/snapshot_bench_test.dart`): a 64 KB fixture, median of 20 decodes ≤ 4 ms. This is a coarse CI guard only; device numbers come from §8.
5. Every integration and widget test in §10.
6. **NFR-17 trace check** (`tool/ci/trace_check.dart`, plain Dart): parses PRD §4 for FR rows marked `M`, parses the test tables of every `docs/06-lld/*.md` (the `Traces` or FR column), and fails listing any Must FR with no test row. Ranges such as `FR-120…124` are expanded. It also fails if a test file named in an LLD table does not exist once the story is marked done (warn only before that).
7. **NFR-18 architecture check** (`test/architecture/import_rules_test.dart`, reads `lib/**.dart` as text): `domain/` imports no `data/`, `presentation/` or `package:flutter`; `data/` imports no `presentation/`; `features/X` imports no `features/Y/presentation` (only `core/` and the openers in `core/navigation`); `features/ai_chat` imports no order/alert repository (TRD §4); no `part '*.g.dart'` or `part '*.freezed.dart'`, no `@riverpod` / `@freezed` / `@JsonSerializable` annotations; together with the pubspec deny-list (check 2).

## 10. Tests
| # | Level | Given / When / Then | Traces |
|---|---|---|---|
| T1 | widget | bootstrap with a `Completer`-backed snapshot future · pump one frame · shell + watchlist skeleton painted while the completer is still pending | TR-14, NFR-1 |
| T2 | widget | snapshot completes with 3 quotes · pump · rows painted, every one stale with "as of" (`freshnessOf` fromCache) | FR-80, FR-81 |
| T3 | widget | cached quote · first live frame for RELIANCE (seq 5 < any) · only RELIANCE turns live | FR-81, ADR-0005 |
| T4 | unit | `AppSnapshot` round-trip `toJson`/`fromJson` equals; decoded quotes `fromCache == true` | TR-15 |
| T5 | unit | file with schemaVersion 0 / savedAt 8 days ago / truncated JSON · read · `null`, file deleted, exactly 1 `cache_discarded` log with the right reason, no throw | FR-87 |
| T6 | unit | `.tmp` present and main file valid · read · main returned, tmp deleted | TR-15 |
| T7 | unit | 3 `write`s while one is in flight · 2 disk writes, the final file = the 3rd map | TR-15 |
| T8 | unit (FakeClock) | scheduler: dirty + 30 s → 1 save; not dirty → 0; offline start with no live data + `onHide` → 0; resync while reconnecting → 0; while live → 1 | TR-15 |
| T9 | unit | prefs: missing → defaults, 0 logs; corrupt → defaults, 1 `prefs_discarded`; 501 seen ids → 500, oldest dropped; `update` visible synchronously in `data` | TR-16, FR-55 support |
| T10 | unit | snapshot `clear()` leaves prefs intact; reset clears both | ADR-0005, FR-112 |
| T11 | widget | after first frame: `find.byType(OptionChainScreen)`, `AiChatScreen`, `PortfolioScreen`, `MoreScreen` find nothing; `container.exists(optionChainControllerProvider)` false | FR-82, TR-13 |
| T12 | widget | select Options then Watchlist · watchlist `ScrollController.offset` unchanged; Options `TickerMode` false while hidden | FR-86, TR-13 |
| T13 | widget | push an opaque `stockDetail` · `screenVisibleProvider(watchlist)` false, `(stockDetail)` true; show a bottom sheet over it · `(stockDetail)` still true; pop · watchlist true | FR-86, TR-12 |
| T14 | widget | opaque route without a ScreenId (risk notice) over Options · `(options)` false | ADR-0004 |
| T15 | integration (TestServer) | push stock page over watchlist · after 300 ms + 100 ms `GET /debug/subscriptions` shows the watchlist ids released and the stock id held | FR-86, NFR-14, TR-11 |
| T16 | integration | watchlist → options → watchlist within 200 ms · 0 unsubscribe frames | TR-11 |
| T17 | integration | lifecycle `hidden` · within 2 s 0 subs and socket closed; 0 reconnect attempts over the next 10 s (fake clock); `shown` → subs restored once | FR-85, NFR-14 |
| T18 | integration | TestServer not started, warm cache · cold start · cached lists painted, badge Offline, no snapshot written on `onHide` | FR-80, TR-15 |
| T19 | widget | throw in a build → `FakeCrashReporter.errors.length == 1`, not fatal; uncaught async error → 1, fatal | NFR-15, TR-24 |
| T20 | unit | `StartupMarks` ignores the 2nd `cache_painted`; `PaintProbeRecorder` latency from fake `FrameTiming`; probe marks are no-ops with `kPerfProbe == false` | FR-125, TR-23 |
| T21 | widget | More: haptics toggle off · `LocalPrefs.data.hapticsEnabled == false`, persisted; reset offline · disabled "Needs connection" | FR-102, FR-112 |
| T22 | widget | overlay toggle on (profile/debug) · timings and FPS text present | FR-114 |
| T24 | unit | `AppSnapshot.toJson` has no `summary` key; seeded portfolio summary equals `PortfolioSummary.compute` of the cached rows | TR-15, D3 |
| T25 | CI script | `trace_check.dart` on a fixture PRD with one Must FR missing from every LLD table · exits 1 naming it | NFR-17 |
| T26 | unit | `import_rules_test` on fixture files: a `domain/` file importing `data/`, and a `part 'x.g.dart'` · both reported | NFR-18 |
| T27 | widget | debug clock: forward preset → `setClock`; backward preset → confirm state, 0 requests; confirm → `reset(t)` + local wipe; cancel → 0 requests; 409 → same confirm (moved from realtime `debug_clock_controller_test`) | FR-111, D7 |
| T28 | widget + integration (TestServer) | Socket Lab: 600 frames → ring holds the last 500; reached from More › Developer; drop button → reconnect seen (moved from realtime `socket_lab_test`) | FR-110, NFR-16 |
| T23 | device | §8 rows NFR-1…6, 16 | NFR-1…NFR-6, NFR-16, NFR-15 |

## 11. Interfaces used (HLD §10.2 v1.1, all approved)
- **Snapshot (D3):** `List<String> get MarketRepository.watchlistIds`; `void MarketRepository.setWatchlist(List<String> ids)` (calls `markStructuralDirty`); `List<Quote> MarketRepository.latestQuotes(Iterable<String> ids)`; `void MarketRepository.seedFromCache(List<Quote> cached)`; `PortfolioBook? get PortfolioRepository.current` with `class PortfolioBook { List<Position> positions; List<Holding> holdings; Funds? funds; }` (funds not cached); `Position`/`Holding` `toJson`/`fromJson` (dev-realtime); `PortfolioSummary.compute(positions, holdings, quotes)` (dev-trading, pure, not cached).
- **Routes (D4):** every opener pushes with `RouteSettings(name: ScreenId.x.name)`; `openStock` uses `pushReplacement` when the top route is `stockDetail`; `openChain` pops to the shell, then `appShellControllerProvider.notifier.select(ScreenId.options)` (D1).
- **Reset (D7):** `DebugClient.reset({DateTime? marketTime})` → `Future<Result<void>>` for More › Reset; on success `SnapshotStore.clear()` and `LocalPrefs.clear()`.
- **dev-realtime:** `PerfMarks.mark('socket_welcome')` in the welcome handler; `PerfMarks.mark('frame_received', seq: seq)` in `_onFrame`; `_merge` replaces `fromCache` values whatever their seq; 300 ms linger (TR-11); a debug load switch so every subscribed symbol changes on each 250 ms flush (NFR-4/5 runs).
- **dev-trading:** the watchlist screen calls the `cache_painted` and `first_live_tick_painted` marks; the probed tile/cell calls `PaintProbe.mark(seq)`; price controllers follow §5.2.
- **dev-ai:** `LiveWhenVisible` ANDs `screenVisibleProvider(ScreenId.ai)`; `ai_first_card_painted` post-frame, `ai_stream_done` at `AnswerDone`, both through `PerfMarks`; `openStrategyBuilder` names its route `ScreenId.strategy.name`.

## 12. App icon and splash (S-61, S-62) — build note

- **Rasteriser:** AppKit `NSImage` via `tool/brand/render_svg.swift`, driven by `tool/brand/generate_icons.sh` (pinned Swift 6.2 / macOS 26). Why: it is the only SVG rasteriser on the dev Mac offline (no `rsvg-convert`, `resvg`, `inkscape`), it needs no pub dependency, and two runs give byte-identical PNGs; `flutter_launcher_icons` / `flutter_native_splash` need PNG input and a pubspec change.
- **Outputs (49 PNGs):** Android `mipmap-*` icon, foreground, monochrome; `drawable-*/splash_logo{,_light}.png` (160 dp, below 12); `drawable-xxxhdpi/splash_icon{,_light}.png` (1152 px, 12+); iOS `AppIcon` (15 files, no alpha) and `LaunchLogo.imageset` (light/dark, 160 pt); `store/play_store_icon.png` (512). `LaunchImage.imageset`, `drawable-nodpi`, `drawable-v21` and `mipmap-anydpi-v33` are removed; the v26 adaptive icon carries the monochrome layer.
- **Deviation:** the iOS image set is `LaunchLogo` (03b §13.3), not `LaunchMark` (story file list). Light resources are the default and dark go in `-night` (the half-built version had them swapped).
- **CI:** `tool/ci/brand_check.dart` (pure-Dart SHA-256 in `tool/ci/sha256.dart`, no `crypto` dependency) checks `generated.sha256`, iOS alpha, adaptive layers and that `lib/` draws no Flutter splash; it runs in `quality_checks.sh`.
