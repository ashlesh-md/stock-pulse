# PRD review: QA (testability)

Reviewer: qa-lead · Input: `docs/02-prd.md` (draft), `docs/01-brief.md`, existing tests in `market_server/test/` and `stock_pulse/test/` · Date: 2026-11-06

## 1. Verdict

**Needs changes before the scope gate.** The PRD is well structured and most Given/When/Then lines can become tests. But the core safety rule (stale = no order) has no defined clock source, several Must items have no negative case, and four NFR budgets have no device, run count or pass rule. None of this needs new scope. It needs tighter wording plus three server test hooks (see §7).

What exists today: server unit tests (engine, broker idempotency, buckets) and REST/WS tests; client tests run against the **real in-process server** (`TestServer`, engine stepped by hand, `eventually()` polling). Debug endpoints `drop-connections`, `freeze` (socket-wide only) and `skip-seq` exist. There is **no `integration_test/` folder** and **no clock injection** outside `Broker`.

## 2. Testability problems and proposed rewrites

Severity: **H** = blocks a reliable test of a Must or a safety rule · **M** = test possible but flaky or arguable · **L** = wording.

| ID | Problem | Proposed acceptance | Sev |
|---|---|---|---|
| §3 stale rule | No clock source or boundary. `asOf` is server time, the age is judged on the client, so device skew breaks it. "Older than 5 s" is not marked inclusive or exclusive | Age = (client now + server offset from hello `serverTime`) − `asOf`. Stale when age **> 5.0 s**. Test: fake clock at 4.9 s → live, at 5.1 s → stale; skew of +30 s on the device does not change the result | H |
| FR-5 / FR-91 | "Socket down 6 s" mixes two triggers. Per-instrument silence cannot be produced (freeze is socket-wide) | G socket live, RELIANCE silent for 5.1 s (per-symbol freeze) · T only the RELIANCE row shows the stale style and "as of hh:mm:ss"; other rows stay live. Separate case: socket not live → all rows stale at once | H |
| FR-38 / NFR-8 | Only the happy path. Missing: stale arrives **after** Confirm is tapped but before the ack; stale on a different instrument than the sheet's | G sheet open, quote live · W freeze, then tap Confirm at 5.1 s · T no POST is sent (server order count unchanged), reason "Price not live" shown. G in-flight POST · W goes stale · T the in-flight order is not cancelled client-side and its final status is shown | H |
| FR-31 | "Double tap" only. Missing: retry after timeout, reconnect mid-submit, app kill with order in flight | G POST times out after the server stored the order · W client retries · T same key, one order on the server, one fill notice, one haptic. G 2 taps 50 ms apart · T exactly 1 POST | H |
| FR-37 | Boundaries not stated (09:15:00.000 inclusive?) and "equity limit only" has no reject text | G clock 09:14:59.9 + option · T confirm disabled "Options open at 09:15". G 09:15:00.0 · T enabled. G Closed · T server rejects with code `market_closed` and the text is shown over the sheet | H |
| FR-84 / NFR-10 | "No wrong price" is not observable | G seq gap · T the client requests resync; no value from a frame with seq < snapshot seq is painted (assert on the provider, not the pixel); no duplicate fill or `alert.triggered` after resync (count = 1) | H |
| FR-24 / E8 | No holiday rule, no test for roll while open | G expiry Tuesday is a holiday in the simulated calendar · T expiry is Monday and badge shows Monday. G chain open on expiring contract · W debug next day · T "Expired" shown, picker moves to next expiry within 1 s | M |
| FR-1 | "Only that row repaints" is not directly assertable | Widget test counts **builds** per row via a build counter / `debugPrintRebuildDirtyWidgets`: one tick on symbol A → row A rebuilt once, other rows 0 | M |
| FR-23 / E9 | "No scroll jump" not measured | G user scrolled to offset X · W ATM moves 2 strikes · T `ScrollController.offset` unchanged (± 0 px) | M |
| FR-33 / NFR-9 | Example hard-codes 65; "never hard-coded" checked by grep is weak | Server fixture overrides lot size to 50 · T sheet shows "100 qty" for 2 lots. Removes the need for a grep check | M |
| FR-34 | Price band not given numbers | G prev close 100, limit 120.05 · T server rejects `price_band`, client shows "Outside price band 80–120" | M |
| FR-51 / FR-54 | "One-shot" vs "delivered on resync" can produce duplicates; no id for dedupe | Each trigger has an `alertId` + `triggeredAt`; client shows one banner per `alertId` even if delivered live and again in the resync | H |
| FR-60 / E13 | "Progressively" not measurable; mid-stream error not in acceptance | G question · T first card painted before the stream ends; server error after card 2 · T cards 1–2 stay + "Answer interrupted · retry" | M |
| FR-63 / NFR-14 | "Subscribe while visible" has no count | Card scrolled off-screen · T server subscription count for that symbol drops within 1 s (ref-counted with watchlist) | M |
| FR-80 / E2 | No cache age limit; corrupt cache case not in acceptance | Add: cache from schema v-1 or truncated JSON · T app starts with network load, one crash-hook log, no crash | M |
| FR-82 | "Startup trace" is not a test | Widget test: after first frame, `find.byType(OptionChainScreen)` finds nothing; chain provider has 0 listeners | L |
| FR-85 / NFR-14 | "Background 30 s" vs "within 2 s" disagree | G app backgrounded · T socket closed within 2 s (fake clock) and no reconnect attempts while paused | M |
| FR-100 | Real device haptic cannot be asserted | Unit/widget: fake `MethodChannel` handler receives exactly 1 `success` per fill id, 1 `rejection` per reject; device check is manual | L |
| FR-12 / NFR-13 | "Bottom 25%" good; 48 dp not in acceptance | Widget test at 360×800: Buy/Sell/Confirm/Exit rects within bottom 25% and ≥ 48×48 dp (`tester.getSize`) | L |
| NFR-11 | No start condition | G server killed and restarted on the same port · T badge Live and prices ticking ≤ 10 s after the server accepts connections; positions match server state | M |
| NFR-12 | "No clipping" not defined; contrast not automated | Golden at 360×800, text scale 2.0, bundled font; plus `tester.takeException()` has no overflow error; `meetsGuideline(textContrastGuideline)` and `androidTapTargetGuideline` pass | M |
| NFR-16 | "No growth" has no limit | Heap after 10 min ticking ≤ heap at 1 min + 10 MB; RSS ≤ 250 MB | M |

## 3. How each NFR budget will be measured

All on the reference device: **named model to be fixed by PM (e.g. Pixel 6a / Android 15 or Moto G-class 4 GB)**, profile build, local server on the same Wi-Fi, battery > 50%, no charger, app data cleared except where a warm cache is needed.

| NFR | Tool | Runs | Pass rule |
|---|---|---|---|
| 1 first frame | `flutter run --profile --trace-startup` → `build/start_up_info.json` (`timeToFirstFrameMicros`); cold = `adb shell am force-stop` before each run | 10 | p50 ≤ 800 ms and p90 ≤ 1.2 s |
| 2 cached content | Custom `Timeline.instantSync('cache_painted')` after first frame with cached rows; read from the same trace | 10 (warm cache) | p50 ≤ 1.0 s |
| 3 first live price | Trace mark `first_live_tick_painted` | 10 | p50 ≤ 2.0 s |
| 4 watchlist | `integration_test` + `binding.traceAction` + `TimelineSummary` (`summary.json`: `average/90th_percentile_frame_build_time_millis`, `missed_frame_build_budget_count`); server ticking 50 symbols at 4 Hz; scripted fling for 20 s | 5, report median | build and raster p90 < 16 ms; missed frames ≤ 1% of total frames; on 90/120 Hz screens report against 16 ms and the native budget separately |
| 5 chain | Same as NFR-4, 40 strikes, 4 Hz, scripted scroll + "Back to ATM"; plus a rebuild counter test (widget level) for "only changed cells" | 5 | Same as NFR-4; rebuilds per tick ≤ changed cells |
| 6 socket → paint | `Timeline` flow: `frame_received(seq)` in the socket layer, `price_painted(seq)` in a post-frame callback of the price cell; compute deltas offline | 3 × 60 s | p90 ≤ 50 ms |
| 11 restart | Integration test against the in-process server: close + re-serve on the same port | 20 in CI loop | 20/20 under 10 s |
| 14 battery / subs | Server exposes subscription counts; integration test asserts counts on background, scroll, card off-screen | each run | exact counts |
| 16 memory | DevTools memory tab, snapshot at 1 min and 10 min with chain open | 2 | see §2 |

Results go to the NFR-15 docs table with device, OS, build SHA, date and raw medians.

## 4. Test levels plan

| Level | Scope | Examples | Runs where |
|---|---|---|---|
| Unit (server) | Pure logic: Black-Scholes, IV smile, expiry calendar, market clock phases, alert crossing, MIS square-off, T+1 roll, tick/band validation, idempotency | Holiday Tuesday → Monday; alert one-shot; 15:20 squares only MIS | `dart test` in `market_server` |
| Unit (client domain) | Stale rule with fake clock and skew, lot/₹ maths, nudges, payoff max loss/breakevens, Indian formatting, resync ordering | 4.9 s vs 5.1 s; straddle breakevens | `flutter test` |
| Widget | Each screen's loading / empty / error / live / stale / closed states; order sheet enable/disable reasons; risk notice once; 200% goldens; a11y guidelines | Sheet disabled "Price not live"; "Debug clock" chip | `flutter test` |
| Integration (in-process server) | Real REST + WS via `TestServer`: freeze → no POST, skip-seq → resync, drop during order, restart, alert resync dedupe, subscription counts | Existing style in `controllers_test.dart` | `flutter test` (fast) |
| Device integration | `integration_test/` on the reference phone: J-2 smoke, NFR-1…6 traces | 09:15 script | `flutter drive --profile` |
| Manual | Haptic feel and distinct patterns, TalkBack / VoiceOver pass, real mobile-data drop (airplane toggle), battery saver, contrast spot check, J-1…J-6 walkthrough | — | Checklist per release |

**Cannot be automated:** haptic feel, real radio loss and captive portals, screen reader usability (only semantics labels are testable), real battery drain, thermal throttling on long sessions.

## 5. Top 10 risk-based scenarios

| # | Scenario | Level | Expected |
|---|---|---|---|
| 1 | Socket drops after POST is stored but before the fill frame; reconnect + resync | Integration | Order shown Pending then Filled; one notice, one haptic |
| 2 | REST timeout, client retries with the same key | Integration (fault hook) | One order on server; UI shows final status, not an error |
| 3 | Freeze 6 s while sheet open with values typed; then live again | Integration + widget | Confirm disabled with reason, inputs kept; re-enabled within one tick |
| 4 | Stale begins during the 100 ms between tap and POST | Widget (fake clock) | No POST |
| 5 | Cold start offline with a cache from yesterday 15:30, then network returns at 09:15 | Integration | Rows "as of 15:30" grey, each turns live on its own tick; nothing shown live before a tick |
| 6 | Skip-seq while flinging the option chain at 4 Hz | Integration + device | Resync replaces values; no older price painted; no scroll jump; no frame > 32 ms |
| 7 | Expiry Tuesday 15:15 → 15:20 → close with MIS and NRML expiring rows | Server unit + integration | MIS squared at 15:20 only; badges correct; expired contract moved to next expiry |
| 8 | Alert crosses while disconnected, then is resent on resync and live | Integration | Exactly one banner per alertId |
| 9 | Pre-open boundary 09:14:59 → 09:15:00 with an option sheet open | Widget (fake clock) | Disabled → enabled without reopening |
| 10 | Server restart mid-session with open positions and a chain open | Integration | Live ≤ 10 s; positions equal server; subscriptions restored once (no duplicates) |

## 6. Questions for the PM

1. Which exact device model and OS is "the reference device"? An emulator does not give valid frame numbers.
2. Is the stale threshold measured against server-adjusted time (my proposal) or raw device time?
3. Is 09:15:00 inclusive for options, and 15:20:00 inclusive for square-off?
4. On a retry after timeout, what does the user see while the client does not yet know if the order exists?
5. Does a stale quote on the **underlying** block an option order whose own premium is live?
6. Max age for the cache before we show empty states instead (e.g. older than 7 days)?
7. Are 90/120 Hz devices judged against 16 ms or their native frame budget?
8. Does the simulated calendar include a holiday list, so FR-24's Tuesday-holiday rule can be tested?

## 7. Test hooks requested from the architect

Injectable `Clock` on server and client; per-symbol freeze (`/debug/freeze?symbol=`); REST fault injection (delay, 5xx, drop ack after store); `/debug/clock` to an exact time; server subscription-count endpoint; Timeline marks for frame received / painted; fake haptics channel. Without the first three, the High items above cannot be tested deterministically.

## Round 2 (PRD v1.1)

Checked against `docs/02-prd.md` v1.1: Change log §0, Review answers §10, the requirement rows themselves, §3.1, §3.2 and §5.

| Item | Status | Note |
|---|---|---|
| H1 stale rule clock and boundary | **Closed** | §3.1: `serverNow = deviceNow + offset` (welcome + pong), age > 5.0 s stale, 5.0 s live; FR-94 has the +30 s skew case; NFR-7 tests 4.9 / 5.0 / 5.1 s |
| H2 per-instrument vs socket stale | **Closed** | FR-5 and FR-91 split the two cases; FR-121 per-symbol freeze; keep-alive ≤ 2 s keeps quiet strikes live |
| H3 stale after Confirm | **Closed** | FR-38 (0 POSTs at 5.1 s), FR-38a (in-flight not cancelled), NFR-8 covers tap-to-send |
| H4 retry / reconnect / kill during submit | **Closed** | FR-31 same key, ≤ 2 retries; FR-31a "checking status", Pending until resync, never auto-resubmit; FR-122 dropAckAfterStore |
| H5 phase boundaries | **Closed** | §3.2 [start, end); FR-37 at 09:14:59.900 / 09:15:00.000; FR-44 at ≥ 15:20:00.000 |
| H6 sequence rule | **Closed** | FR-84: no value with seq < snapshot seq applied; resync reloads orders, positions, alerts; counts = 1 |
| H7 alert dedupe | **Closed** | FR-51 `alertId` + `triggeredAt`; FR-55 persisted seen-set, 1 banner per id |
| Q1 reference device | **Closed for QA, pending user** | §5.1 Pixel 6a / Android 15 at 60 Hz, iPhone 13 secondary; Gate 1 confirms. Not blocking: the rules hold for any 4–6 GB Android named there |
| Q2 clock source | **Closed** | Server-adjusted (§3.1) |
| Q3 09:15 / 15:20 inclusive | **Closed** | Both inclusive (§3.2) |
| Q4 view during retry | **Closed** | FR-31a |
| Q5 stale underlying | **Closed** | Block on traded contract only; E20 nudge |
| Q6 max cache age | **Closed** | FR-87: 7 days |
| Q7 90/120 Hz | **Closed** | 16.7 ms pass rule, native figure reported (§5.2) |
| Q8 holiday list | **Closed** | §3.2 config table, tests inject; FR-24 fixture holiday |
| Test hooks (§7) | **Closed** | FR-120…FR-126 as Must; NFR-17 requires them before dependent stories |

**Notes for the test plan (not blockers):**
- §3.1 checks staleness on a 250 ms timer (detected within 5.25 s), while FR-38 taps at 5.1 s. Confirm must re-check the rule at send time, not read the last timer result. I will test it at exactly 5.1 s with a fake clock.
- NFR-4 has the build p90 at "< 16 ms" but §5.2 sets the pass rule at 16.7 ms. I will use 16.7 ms as the gate and report both.

**Round 2 result: all 7 High items closed; the PRD is testable.** The QA sign-off waits for the release.
