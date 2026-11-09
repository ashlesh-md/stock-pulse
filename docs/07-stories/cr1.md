# 07 · Stories part CR-1: new stories S-52…S-76 (v2.0)

Status: **v2.1** · Author: scrum-master · Parent: `../07-stories.md` (change log, waves, coverage) · Sources: `02-prd.md` v1.4
(§4.8a, §4.13–4.17, §5.3, §7a), `03-ux-spec/10…15`, `03b-design-system/10…14`, `05-hld.md` v2.0, ADR-0009…0021,
`06-lld/README.md` §6 (R-0…R-5 are defined there and on the board; not repeated here).

Every story here is written for the v2.0 rules: four layers per feature, providers in `<f>_providers.dart`, `Success` /
`Failure` / `AppError`, package imports, ≤ 300 lines per file, `AppStrings` / `AppIcons` / `AppImages`, messages through
`FeedbackController.show` with a `<feature>.<reason>[.<id>]` key, routes in `<f>_routes.dart`, 100 % line coverage, red
run recorded before green (NFR-19, NFR-20, NFR-24).

## 0. Change log

| # | Change | Source |
|---|---|---|
| v2.1 | `features/chart/` confirmed, one owner per file (HLD v2.1 D14, LLD README §6.4); maths stay in `domain/indicators/` (D15); **S-71 → dev-ai** with only `fib_levels.dart` + `fib_painter.dart`, S-55 builds the generic two-anchor path and the gated Fib tool, S-52 ships the Fib stubs (D16); locale files named `<area>_strings_en.dart`; counts dev-trading 11, dev-ai 5 | architect |

## 1. New epics

| Epic | Name | FR / NFR / ADR |
|---|---|---|
| CR-1 | Refactor wave W1R (R-0…R-5, board) | ER-1…ER-10, NFR-19, NFR-24; ADR-0009…0021 |
| E12 | Advanced stock chart (Kite-style) | FR-130…152, NFR-23 |
| E13 | Shared UI kit: picker, feedback, strings, assets | FR-155…157, FR-160…164; ADR-0018, ADR-0019 |
| E14 | Brand, icon, splash, startup | FR-170…172, NFR-22 |
| E15 | Links, push, analytics | FR-175…189; ADR-0015…0017 |
| E16 | Failure cases and quality gates | §7a F1…F18, NFR-19…21, NFR-24; ADR-0020, ADR-0021 |

## 2. Ownership of the new `features/chart/` module (confirmed: HLD v2.1 D14–D16, `06-lld/README.md` §6.4)

The chart outgrows `market/presentation/stock_detail` (five Must FRs, three owners). It becomes its own feature folder,
split by file like the v1.1 shared folders:

| Path under `stock_pulse/lib/features/chart/` | Owner |
|---|---|
| `domain/indicators/**` (pure Dart maths, `study_spec`, `study_catalog`), `domain/fib_levels.dart`, `presentation/drawings/fib_painter.dart` | dev-ai |
| `application/studies/**`, `presentation/studies/**` (sheet, chips, overlay layer, lower panes) | dev-ai |
| `domain/chart_store.dart`, `data/**`, `chart_providers.dart` | dev-realtime |
| everything else: `domain/{chart_layout,drawing,chart_range,drawing_geometry,tick_snap}.dart`, `application/{chart_*,drawings/**}`, `presentation/**` except `studies/` and `drawings/fib_painter.dart` | dev-trading |

Contract: S-52 ships compiling stubs of the dev-ai files that dev-trading mounts (`StudyOverlayLayer`, `StudyPaneStack`,
`StudyChipRow`, `showStudiesSheet`, `studiesControllerProvider` with an empty list, `fibLevels(a, b) → const []`, a no-op
`FibPainter.paint` and `const bool fibToolReady = false`), so S-53 and S-55 never edit a dev-ai file.
`AppIcons` and `core/l10n/app_strings.dart` stay dev-trading files: other owners add their own `strings/<area>_strings.dart`
and `locales/en/<area>_strings_en.dart` and ask dev-trading for new icons at the start of their story.

## 3. Stories

Format: `#### ID · title · owner · size · trace · depends`, then files, then Given / When / Then.

### E12 · Advanced chart (Must)

#### S-52 · Indicator maths: SMA, EMA, VWAP, RSI with one-index updates · dev-ai · M · FR-131…134 (maths), FR-138, F9, ADR-0009, ADR-0014 · dep R-3, R-1b (`Candle` in `market/domain`)
- Files: `features/chart/domain/indicators/{study_kind,study_spec,study_series,indicator,sma,ema,vwap,rsi,study_catalog}.dart`; stubs `features/chart/application/studies/studies_controller.dart`, `features/chart/presentation/studies/{study_overlay_layer,study_pane_stack,study_chip_row,studies_sheet}.dart`, `features/chart/domain/fib_levels.dart` (`fibLevels` → `const []`, `fibToolReady = false`), `features/chart/presentation/drawings/fib_painter.dart` (no-op); `core/l10n/strings/studies_strings.dart` (interface for S-53); `test/features/chart/domain/indicators/**`, `test/fixtures/chart/{closes_60,intraday_5m}.json`.
- AC1: Given the 60-close fixture, when SMA(20) and EMA(9) run, then every value equals the reference table to 2 dp; SMA's first 19 points are `null`; the EMA seed is the SMA of the first 9.
- AC2: Given 1D 5m candles, when VWAP runs, then candle 3 = Σ(typical × vol) / Σvol of candles 1–3 and it resets at the next 09:15 IST open; given a 1d interval, then `supportsInterval` is false.
- AC3: Given the fixture, when RSI(14) runs with Wilder smoothing, then values equal the reference to 2 dp and stay in 0–100.
- AC4: Given 500 candles and 4 studies, when one tick changes the last candle or appends one, then each study's `update` writes exactly 1 index (counter in test); given SMA(200) on 120 candles, then `StudySeries.notEnoughData` (F9).
- AC5: Given `features/chart/domain/**`, then the layer test finds no Flutter (except `foundation`), riverpod, `http` or `dart:io` import; the stubs compile and render `SizedBox.shrink`.

#### S-53 · Chart module: `ChartController`, readout row, toolbar · dev-trading · M · FR-10, FR-11, FR-139, FR-155 (interval, type), FR-175 (`?range=&interval=`), FR-187 (`chart_opened`, `chart_setting_changed`), ADR-0009, ADR-0015 · dep S-18, S-59, S-52 (stubs), R-5 (fake sink until done)
- Does: moves R-2's split chart (`candle_geometry`, painter, crosshair layer) out of `market/presentation/stock_detail/widgets/` into `features/chart/`; `ChartController` (family by instrument id) owns range, interval, type, crosshair candle and `ChartLayout`; `ChartToolbar` (6 × 48 dp portrait row; Studies opens `showStudiesSheet`); `ReadoutRow`; `Drawing` and `ChartLayout` entities with JSON; the stock page mounts `ChartView`. Keeps S-18's `interactive` / `showVolume` flags for dev-ai's mini chart.
- Files: `features/chart/domain/{chart_layout,drawing,chart_range}.dart`, `features/chart/application/{chart_controller,chart_state}.dart`, `features/chart/presentation/{chart_view,chart_toolbar,readout_row,candle_painter,candle_geometry,crosshair_layer}.dart`, `features/market/presentation/stock_detail/stock_detail_screen.dart` (mount only), `core/l10n/strings/chart_strings.dart`, `core/l10n/locales/en/chart_strings_en.dart`, `core/assets/app_icons.dart` (studies, draw, expand, settings), tests.
- AC1: Given the crosshair on candle 10, then the readout shows that candle's O, H, L, C, volume and change % in tabular figures; released → the last candle; an instrument stale per §3.1 → "as of hh:mm:ss".
- AC2: Given the interval and type controls, then both are `SpPicker`s (0 `PopupMenuButton` left under `stock_detail/`); a change logs 1 `chart_setting_changed` and fetches candles once.
- AC3: Given a `ChartLayout` with 2 drawings and 2 studies, when it round-trips through `toJson` / `fromJson`, then the result `==` the input (S-56 stores it).
- AC4: Given `/stock/RELIANCE?range=1W&interval=15m`, then the chart opens at 1W 15m; unknown values fall back to defaults without a message.
- AC5: Given a tick, then only the last candle repaints (painter repaint counter) and the readout rebuilds only when its candle changes.

#### S-54 · Studies sheet, chips, overlays, lower panes, 4-study limit · dev-ai · M · FR-130, FR-131…134 (UI), FR-133 (intraday chip), F9, FR-156 (undo), FR-187 (`study_added`, `study_removed`), NFR-12 · dep S-52, S-53, S-59, S-56 (fake `ChartStore` until done)
- Files: `features/chart/application/studies/{studies_controller,studies_state}.dart` (replaces the stub), `features/chart/presentation/studies/{studies_sheet,study_params_editor,study_chip_row,study_overlay_layer,study_pane_stack,pane_painter}.dart`, `core/l10n/strings/studies_strings.dart` (fills S-52's interface), `core/l10n/locales/en/studies_strings_en.dart`, tests + goldens.
- AC1: Given 4 active studies, when the Studies sheet opens, then every `+` is disabled and the inline warn line "You can use up to 4 studies. Remove one to add another." shows (not a snackbar); a 3rd lower pane is refused.
- AC2: Given RSI(14) at 360×800, then a lower pane ≥ 64 dp with 30 / 70 guides; dragging the divider clamps between 64 dp and 40 % of the chart.
- AC3: Given 1Y 1d with VWAP, then chip "VWAP: intraday only" and no line; given SMA(200) on 120 candles, then chip "Not enough data for SMA(200)" and no line (F9).
- AC4: Given a chip's ✕, then the study is removed with one undo snackbar via `FeedbackController` (key `chart.study_removed.<id>`, 4 s); Undo restores the same parameters; `study_added` / `study_removed` fire once each; the layout is saved through `ChartStore`.
- AC5: Given the palette slots (03b 11.2), then no study colour equals an up / down colour; goldens pass light / dark at 1.0× and 2.0×; `pane_painter` draws line and histogram series (MACD uses it in S-70).

#### S-55 · Drawing tools: horizontal and trend line · dev-trading · L · FR-140, FR-141, FR-143 (save calls), F11 (save fails), FR-187 (`drawing_added`), NFR-12 · dep S-53, S-56 (fake `ChartStore` until done)
- Does (D16): adds `DrawingKind.fibRetracement` to `Drawing` (+ JSON); `drawings_controller` places, drags, saves and limit-counts every two-anchor kind the same way; `drawing_painter` delegates the Fib kind to dev-ai's `FibPainter`; the toolbar's Fib tool shows only when `fibToolReady`.
- Files: `features/chart/domain/{drawing,drawing_geometry,tick_snap}.dart`, `features/chart/application/drawings/{drawings_controller,drawings_state}.dart`, `features/chart/presentation/drawings/{drawing_layer,drawing_painter,drawing_handle,drawing_action_bar}.dart` (not `fib_painter.dart`), `features/chart/presentation/chart_toolbar.dart` (✎ selected state, gated Fib tool), tests.
- AC1: Given draw mode, when the user taps at ₹1,500.02 (tick 0.05), then a horizontal line sits at 1,500.00 with an axis price tag and draw mode ends (one-shot).
- AC2: Given two taps, then a trend line joins both (time, price) anchors; dragging a handle moves only that end, dragging the body moves both; each handle's hit area is ≥ 44 dp.
- AC3: Given a selected line, when Delete on the action bar, then it is gone and saved; the 21st drawing on a symbol is refused with an inline message (limit 20).
- AC4: Given a trend line, when the range changes 1D → 1W, then it stays at the same (time, price); `ChartStore.save` runs once per edit (debounced 500 ms); the store failing → one snackbar "Couldn't save drawing", the line kept in memory (F11).
- AC5: Given `fibToolReady == false`, then no Fib tool in the toolbar; a stored `fibRetracement` drawing still loads, drags and counts toward the limit (fake `FibPainter`).

#### S-56 · `ChartStore`: layouts per symbol and chart prefs, saved locally · dev-realtime · M · FR-143, FR-147 (store), FR-112 (wipe), F6 (bad file), F11, ADR-0009, ADR-0010 · dep S-53 (`ChartLayout` JSON), R-4 (storage layering)
- Files: `features/chart/domain/chart_store.dart` (interface: `load(symbol)`, `save(symbol, layout)`, `loadPrefs()`, `savePrefs(prefs)`, `clearAll()`), `features/chart/data/local_chart_store.dart` (one JSON file per symbol, `.tmp` + rename, over `core/storage` file helpers), `features/chart/chart_providers.dart`, tests.
- AC1: Given a trend line and RSI saved for RELIANCE, when a fresh container loads it (restart), then the layout `==` the saved one.
- AC2: Given a truncated file or an unknown `schemaVersion`, when `load` runs, then empty layout, file deleted, one log, no throw (F6).
- AC3: Given the disk write throws, then `save` returns a `Failure`, nothing is marked saved, the next save retries (F11).
- AC4: Given `clearAll`, then no layout or prefs file remains (reset, S-46); given `savePrefs(1M, 1d, line)`, then `loadPrefs` returns it after restart.

#### S-57 · Landscape full-screen chart · dev-trading · M · FR-144, FR-175 / FR-176 (`/stock/{symbol}/chart`), FR-187 (`chart_fullscreen`), NFR-23 (state kept), ADR-0015 · dep S-55, S-54, R-5
- Files: `features/chart/presentation/fullscreen/{fullscreen_chart_screen,chart_rail}.dart`, `features/chart/presentation/chart_view.dart` (expand button), `features/market/presentation/market_routes.dart` (`/stock/:id/chart`), tests.
- AC1: Given 1W 15m + RSI + 1 line and a crosshair, when expand then exit, then the same range, interval, type, studies, drawings and crosshair, and 0 extra candle fetches (fake repository counter).
- AC2: Given the stock page, when the device rotates to landscape, then the full-screen route opens; on exit or system back the app returns to portrait (`SystemChrome` orientations restored).
- AC3: Given landscape, then tools are on the left rail, the connection badge and stale "as of" are visible, the plot is ≥ 60 % of the height, pickers and the Studies sheet open as 360 dp side sheets.
- AC4: Given a cold start with `stockpulse://stock/RELIANCE/chart`, then the full-screen chart; Back → stock page → Watchlist root.

#### S-58 · Buy / Sell from the full-screen chart · dev-trading · S · FR-145, FR-30…39a (reuse), FR-92, FR-113, FR-178, FR-187 (`order_sheet_opened` source `chart`) · dep S-57, S-28b, S-30
- Files: `features/chart/presentation/fullscreen/chart_trade_rail.dart`, `features/orders/presentation/order_ticket_side_sheet.dart` (landscape host for the same ticket body, Q-UX-1), tests.
- AC1: Given full-screen RELIANCE, when Buy, then the existing ticket opens as a right side sheet with the chart visible, side Buy prefilled; Confirm is still required and 0 POSTs happen before it; `order_sheet_opened{source: chart}` fires once.
- AC2: Given NIFTY, then no Buy / Sell on the rail; given a stale price, then Confirm is blocked with its reason (FR-92), no snackbar.

### E13 · Picker, strings, assets

#### S-59 · `SpPicker` component · dev-trading · M · FR-155, NFR-12, NFR-13, 03b part 10, UX part 11 · dep R-2
- Files: `core/widgets/sp_picker/{sp_picker,sp_picker_option,sp_picker_trigger,sp_picker_sheet,sp_segmented,sp_multi_picker}.dart`, `core/assets/app_icons.dart` (tick, chevron), `core/l10n/strings/common_strings.dart` (Done, Loading), `test/core/widgets/sp_picker/**` + goldens.
- AC1: Given ≤ 4 short options, then a segmented control; more options or long labels → sheet list; segmented falls back to the sheet at large text (UX 11.1 rule).
- AC2: Given the sheet open, then rows ≥ 48 dp, a selected tick, semantics "selected"; `androidTapTargetGuideline` and `textContrastGuideline` pass; goldens match light / dark at 1.0× and 2.0×.
- AC3: Given a tap on an option, then `onChanged` fires once and the sheet closes; multi-select returns on Done; disabled rows do nothing; loading shows a 20 dp indicator and "Loading..." (no shimmer).

#### S-60 · `SpPicker` adoption close-out and no-dropdown gate · dev-trading · S · FR-155, FR-187 (`watchlist_row_action`, `error_shown` if not yet logged) · dep S-59, S-27, S-28a, S-43, S-44, S-67
- Files: remaining choice widgets in dev-trading presentation files (chain columns, alert direction, SL type), `core/feedback/application/feedback_controller.dart` (`error_shown`), `features/market/presentation/watchlist/**` (`watchlist_row_action`), tests.
- AC1: Given `lib/`, when S-67's `no_dropdown_check` runs, then 0 `DropdownButton`, `DropdownMenu` or choice `PopupMenuButton`; the check is blocking from the W3 exit.
- AC2: Given each place in UX 11.2 (chart type, interval, study parameters, order type, product, chain columns, alert direction), then a widget test finds an `SpPicker` there.

#### S-67 · CI checks: string literals, asset and icon registry, formatters, dropdowns · dev-perf · S · FR-155, FR-160, FR-162, FR-163, ADR-0018, ADR-0021, NFR-24 · dep R-0, R-2
- Files: `tool/ci/{string_literal_check,asset_registry_check,formatter_check,no_dropdown_check}.dart`, `test/tool/ci/**`, CI workflow lines.
- AC1: Given fixtures with `Text('Buy')` in presentation, `Icons.add` outside `core/assets`, `'assets/x.png'`, `NumberFormat(` outside `core/format` and a `DropdownButton`, then each check reports file:line; symbols, numbers and Socket Lab frame text are exempt by an allow-list in the tool (no pragmas).
- AC2: Given the real tree, then the checks run report-only in W2–W3; `no_dropdown_check` turns blocking at the W3 exit, the other three at the W4 exit.

#### S-68 · Formatter `en_IN`, plurals, every key and asset resolves · dev-trading · S · FR-161, FR-162, FR-163, F18, ADR-0018 · dep R-2
- Files: `core/format/{app_formatter,number_formats,date_formats}.dart`, `core/assets/app_images.dart` (placeholder), `test/core/format/**`, `test/core/l10n/{plural_test,all_keys_resolve_test}.dart`, `test/core/assets/all_assets_resolve_test.dart`.
- AC1: Given 1234567.5, then "₹12,34,567.50"; percentages, dates and times come from one formatter keyed on the locale (`en_IN`).
- AC2: Given 1 and 2 lots, then "1 lot" / "2 lots" from one `plural` call; a test over `locales/en` finds no sentence built by concatenation.
- AC3: Given every `AppStrings` area getter and every `AppImages` path, then each resolves to a non-empty string or a bundled asset; a missing asset renders the registry placeholder (F18).

### E14 · Brand and startup

#### S-61 · App icon and native splash, generated from the brand SVGs · dev-perf · M · FR-170, FR-171, NFR-22, NFR-1…3, 03b part 13 · dep R-0
- Files: `tool/brand/generate_icons.sh` (one pinned rasteriser), `tool/brand/generated.sha256`, `tool/ci/brand_check.dart` (+ test), `android/app/src/main/res/{mipmap-*/ic_launcher*.png,mipmap-anydpi-v26/ic_launcher.xml,values/styles.xml,values-v31/styles.xml,values/colors.xml,drawable/launch_background.xml}`, `ios/Runner/Assets.xcassets/{AppIcon.appiconset,LaunchMark.imageset}/**`, `ios/Runner/Base.lproj/LaunchScreen.storyboard`. Source: `stock_pulse/assets/brand/{app_icon,app_icon_foreground,app_icon_monochrome,splash_logo}.svg`.
- AC1: Given the four SVGs, when `generate_icons.sh` runs twice, then the PNGs are byte-identical and `generated.sha256` is unchanged; `brand_check` fails CI if a PNG no longer matches its SVG hash.
- AC2: Given the iOS PNGs, then none has an alpha channel (flattened on `#0E1116`); the Android adaptive icon has foreground, background and monochrome layers; release builds show the icon and the asset catalog builds with 0 warnings.
- AC3: Given a cold start, then only the native splash shows (Android 12+ SplashScreen API, launch theme below 12, iOS storyboard) and it is removed at the first Flutter frame; no Flutter splash route and no delay (grep + T1); an NFR-1 smoke run is within 5 % of the pre-story number.

#### S-62 · Dark splash and icon background · dev-perf · S · FR-172 (S) · dep S-61
- Files: `android/app/src/main/res/{values-night,values-night-v31}/styles.xml`, `values-night/colors.xml`, `ios/Runner/Assets.xcassets/LaunchBackground.colorset/**`, `ios/Runner/Base.lproj/LaunchScreen.storyboard`.
- AC1: Given the system in dark mode, when the app cold starts, then the splash background is the dark brand colour on Android 12+, Android < 12 and iOS (resource test + recorded manual check).

### E15 · Links, push, analytics (Should; Musts are in R-5)

#### S-74 · Notification permission asked in context · dev-perf · S · FR-181 (S), F10 · dep R-5, S-43, S-35
- Files: `core/push/application/push_permission_controller.dart`, `features/more/presentation/settings/notifications_row.dart`, tests. S-43 calls `afterFirstAlert()` (stub from R-5).
- AC1: Given first launch, then no permission prompt; given the first alert created, then the explainer, then the OS prompt once; denied → in-app banner unchanged, Settings "Notifications off", asked again only from Settings.

#### S-75 · Analytics on / off in Settings · dev-perf · S · FR-189 (S), FR-188 · dep R-5, S-35
- Files: `features/more/presentation/settings/analytics_row.dart`, `features/more/application/settings_controller.dart`, tests (`LocalPrefsData.analyticsConsent` from R-4).
- AC1: Given analytics off, when J-2 runs, then the fake sink gets 0 events; on again → events flow; the choice survives a restart.

### E16 · Failure cases (one story per area; every §7a row ends with ≥ 1 named test, NFR-21)

#### S-63 · Failures: network, REST, socket, server (F2–F8) · dev-realtime · L · NFR-21, F2, F3, F4, F5, F6, F7, F8, FR-31, FR-84, NFR-11 · dep S-40, S-8
- Files: `core/network/data/{api_client,retry_policy}.dart` (one read retry, `Retry-After`, no retry on 401), `test/core/network/failures/**`, `test/features/*/data/fixtures/bad/**`, `integration_test/realtime/failures/{drop,restart,skew}_test.dart`, `market_server/test/failures/**`.
- AC1 (F2): Given `/debug/drop`, then Reconnecting → Offline and prices stale within 5.25 s; REST reads fail fast with `NetworkError`.
- AC2 (F3, F5): Given a read with `delayMs` past the timeout or status 503, then one retry after 1 s, then `Failure(NetworkError | ServerError)`; order POSTs keep the FR-31 path (same key, ≤ 2 retries) with no extra retry layer.
- AC3 (F4): Given 400 / 422 / 401 / 404 / 409 / 429, then the server reason is mapped; 401 → 1 call, no loop; 409 → the original order; 429 → waits `Retry-After` (default 2 s), ≤ 1 automatic retry.
- AC4 (F6): Given a bad fixture per DTO (missing field, wrong type, unknown enum), then `ParseError`, nothing thrown past `data/`; a bad socket frame is dropped, counted and logged once per type; a skipped seq → 1 resync.
- AC5 (F7, F8): Given 20 restart loops, then Live ≤ 10 s each with the new session id accepted; device clock +30 s, −30 s and a jump → freshness unchanged, re-synced at the next pong.

#### S-64 · Failures: trading screens (F1 widget, F4 UI, F9, F12, F17) · dev-trading · M · NFR-21, F1, F4, F9, F12, F17, FR-156 · dep S-63, S-42, S-43, S-58
- Files: `test/features/{market,options,orders,portfolio,alerts,chart}/presentation/failures/**`, `integration_test/trading/kill_mid_order_test.dart`, empty-state fixes in dev-trading presentation files.
- AC1 (F9): Given no candles, an empty watchlist, no chain, and no positions, holdings, orders or alerts, then each screen shows its designed empty state with its action; no endless spinner, no fake zero.
- AC2 (F17): Given a disabled Confirm tapped 5 times in 1 s, then 0 snackbars (reason focus + haptic, UX part 12); a rejected order re-tried 5 times → exactly 1 snackbar.
- AC3 (F12): Given the app killed during a POST (`dropAckAfterStore`), when relaunched, then Pending → final status, 0 resubmits, 1 notice and 1 haptic.
- AC4 (F1, F4): Given no network with a cache, then Offline badge and grey "as of" rows; no cache → "Connecting… · Retry"; a 401 → the "Demo session expired · Restart demo" treatment once (per the Q-UX-3 answer); 422 → reason text, never a raw code.

#### S-65 · Failures: startup, storage, lifecycle, router, push, analytics + §7a trace · dev-perf · M · NFR-21, NFR-22, F1, F10, F11, F13, F14, F15, F16, FR-177, FR-187, FR-188 · dep R-5, S-46, S-36
- Files: `test/core/{storage,push,analytics,visibility}/failures/**`, `test/app/router/deep_link_failures_test.dart`, `integration_test/startup/offline_cold_start_test.dart`, `integration_test/analytics/journey_events_test.dart`, `tool/ci/failure_trace_check.dart` (+ test), CI workflow line.
- AC1 (F1, I): Given the server down at cold start with a cache, then cached rows paint stale and the socket backs off; no cache → the E1 empty states.
- AC2 (F11): Given the snapshot, prefs or seen-set store throwing, then the app runs from memory, logs once, retries at the next save, and shows no duplicate banner in the same run.
- AC3 (F14, F15, F16): Given `/stock/XYZ`, an unknown push type, a token failure and a sink that throws on every call, then Watchlist + 1 "Link not available"; ignored + 1 log; no-op fallback; J-2 completes with 1 log, 0 crashes, no frame blocked.
- AC4 (F10, F13): Given notifications denied, then Settings "Notifications off" and in-app alerts unchanged; app hidden mid-stream → socket closed ≤ 2 s.
- AC5: Given J-1…J-6 with a fake sink, then the FR-187 events fire once per action with their params; given §7a, when `failure_trace_check` runs, then every F1…F18 maps to ≥ 1 named test (blocking at the W4 exit).

#### S-66 · Failures: AI chat (F6, F9, F13) · dev-ai · S · NFR-21, F6, F9, F13, FR-60, FR-67 · dep S-45
- Files: `test/features/ai_chat/failures/**`, `market_server/test/ai/failures/**`, fixes in dev-ai files.
- AC1 (F6): Given a malformed NDJSON line, an unknown card type and `v = 2`, then a text fallback card each; the stream continues; one log per type.
- AC2 (F13): Given the app hidden mid-answer, then the request is cancelled, received cards stay with "interrupted", the server's `activeAiAnswers` is 0 within 1 s; on resume Retry is offered.
- AC3 (F9): Given an empty history, then the empty state with suggestion chips; a chart card with 0 points → text fallback.

### Should stories (E12, E13, E14)

#### S-70 · Bollinger Bands and MACD · dev-ai · S · FR-135 (S), FR-136 (S), FR-138 · dep S-54
- Files: `features/chart/domain/indicators/{bollinger,macd}.dart`, `study_catalog.dart`, tests.
- AC1: Given the fixture, then BB(20, 2σ population) upper / mid / lower and MACD(12, 26, 9) line / signal / histogram equal the reference to 2 dp; the histogram uses the 03b 11.2 colours plus a shape cue; a tick updates 1 index per series.

#### S-71 · Fibonacci retracement · dev-ai · S · FR-142 (S), D16 · dep S-55
- Files: `features/chart/domain/fib_levels.dart` (replaces S-52's stub; flips `fibToolReady` to true), `features/chart/presentation/drawings/fib_painter.dart`, tests. Placement, drag, save and limit come from S-55's two-anchor path.
- AC1: Given points 100 → 200, then levels 0, 23.6, 38.2, 50, 61.8, 100 % with 61.8 % at 161.80; it saves like other drawings and counts toward the 20 limit.

#### S-72 · Chart settings: log scale, gridlines, remembered state · dev-trading · M · FR-146 (S), FR-147 (S), FR-187 · dep S-56, S-57
- Files: `features/chart/presentation/chart_settings_sheet.dart`, `features/chart/presentation/candle_geometry.dart` (log axis), `features/chart/application/chart_controller.dart` (prefs).
- AC1: Given log on at 5Y, then equal % moves have equal pixel heights (±1 px); gridlines off → none; both saved.
- AC2: Given 1M + line set, when relaunched and any stock opens, then 1M + line; deep-link args still win.

#### S-73 · Alert and limit order at a chart price · dev-trading · M · FR-148 (S), FR-149 (S), FR-178 · dep S-55, S-43, S-28a
- Files: `features/chart/presentation/{crosshair_menu,line_menu}.dart`, `features/chart/presentation/crosshair_layer.dart`, `features/chart/presentation/drawings/drawing_action_bar.dart`, tests.
- AC1: Given the crosshair at 1,512.35, when Set alert, then the alert form shows 1,512.35 with the direction from LTP.
- AC2: Given a line at 1,480, when Buy limit, then the ticket opens Limit 1,480.00 snapped to tick and 0 POSTs; on NIFTY only Set alert is offered.

#### S-69 · Pseudo-locale and overflow check · dev-trading · S · FR-164 (S) · dep S-68, S-42, S-27, S-28a
- Files: `core/l10n/locales/pseudo/**` (debug only: +40 % length, accents), `core/l10n/app_strings_delegate.dart`, `test/l10n/pseudo_overflow_test.dart`.
- AC1: Given the pseudo-locale at 360×800, then watchlist, chain, order sheet and portfolio have no overflow (`takeException` null); a key missing in a locale falls back to English.

### E11 / E12 · Perf

#### S-76 · Chart rendering perf run · dev-perf · M · NFR-23, NFR-4 (method) · dep S-57, S-54, S-55, S-48a, S-49
- Files: `integration_test/perf/chart_perf_test.dart`, `tool/perf/frames.sh` (chart mode), `docs/perf-results.md` (chart row).
- AC1: Given 4 studies incl. RSI and 10 drawings on 1D 1m at 4 Hz, with a scripted pan + pinch for 20 s, 5 runs, then median build and raster p90 < 16 ms and missed frames ≤ 1 %; a rotation keeps state with 0 refetches.

## 4. Counts

| Owner | New stories | Size mix |
|---|---|---|
| dev-trading | 11: S-53, S-55, S-57, S-58, S-59, S-60, S-64, S-68, S-69, S-72, S-73 | 1 L, 6 M, 4 S |
| dev-perf | 7: S-61, S-62, S-65, S-67, S-74, S-75, S-76 | 3 M, 4 S |
| dev-ai | 5: S-52, S-54, S-66, S-70, S-71 | 2 M, 3 S |
| dev-realtime | 2: S-56, S-63 | 1 L, 1 M |
| **Total** | **25** (17 Must-driven, 8 Should) | |

Could items (FR-137 Supertrend, FR-150 hollow candles, FR-151 compare, FR-152 prev/next) are in the parent's backlog.
