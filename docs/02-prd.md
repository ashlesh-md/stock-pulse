# 02 · PRD: StockPulse v2

Owner: product manager · Version: **v1.5** (7 Nov 2026) · Status: CR-1 scope added, aligned with ADR-0018/0019 and UX spec v2.0; for review by architect, designers, qa-lead; user check-in at wave 1 (§11b)
Input: `00-intake.md`, `01-brief.md`, `09-change-request-1.md`, reviews `team/reviews/prd-qa.md`, `team/reviews/prd-architect.md`, `team/reviews/kite-chart-study.md`, `03-ux-spec.md` §9, `03b-design-system.md`
Next: HLD v2 + ADRs (architect), UX/design updates (ux-designer, ui-designer), test plan + failure tests (qa-lead), stories (scrum master)

---

## 0d. Change log v1.5 (CR-1 alignment, 7 Nov 2026)

| # | Item | Change | Driven by |
|---|---|---|---|
| C30 | FR-160, FR-161, FR-164, NFR-18, NFR-19, §9 | **Strings follow ADR-0018**: the requirement is all user-facing text in one localisation-ready place; the mechanism (hand-written `AppStrings` per locale, no ARB / gen_l10n, because gen_l10n generates code and the user forbids codegen) is the architect's. NFR-18 gen_l10n exception removed. NFR-19 stays closed: locale string tables are covered by a test that reads every string, not excluded | Scrum master; ADR-0018 |
| C31 | FR-156, FR-157 | **One-snackbar rule settled** with ADR-0019 and UX 12: three priorities (order outcome > error > info); a lower one never replaces a higher one and waits in **one slot** (newest wins; ADR-0019 v2.1); same key, or same key shown < 4 s ago, dropped. A disabled Confirm shows its inline reason + haptic, no snackbar. User request ("only one snackbar on repeated bad taps") holds: never more than 1 on screen, at most 1 waiting | Scrum master; ADR-0019; UX 12 |
| C32 | FR-145 | **Q-UX-1 accepted**: in landscape full-screen the order ticket opens as a right side sheet (400 dp, full height), chart stays visible; same ticket, same Confirm and blocks | ux-designer Q-UX-1 |
| C33 | §7a F4 | **Q-UX-3 accepted**: 401 is a state, so a persistent session banner "Demo session expired · Restart demo" under the app bar (not a snackbar); server actions disabled, cached content readable | ux-designer Q-UX-3 |

## 0c. Change log v1.4 (CR-1, 7 Nov 2026)

| # | CR item | Change | Driven by |
|---|---|---|---|
| C19 | CR-1.0 | **Advanced charts** (§4.8a, FR-130…FR-152): SMA, EMA, VWAP, RSI pane, OHLC/indicator readout, horizontal + trend line, per-symbol saving, landscape full-screen, Buy/Sell from chart (Must); Bollinger, MACD, Fibonacci, log scale + gridlines, remembered chart state, alert / limit at a chart price (Should); Supertrend, hollow candles, compare, prev/next symbol (Could). Renko/Kagi/P&F, extra intervals, full library, layouts, order lines, GTT → Later. Instant order placement rejected (D-4). Basis: `team/reviews/kite-chart-study.md` | User CR-1.0, Kite study |
| C20 | CR-1.0b | **Designed picker** `SpPicker` replaces every `DropdownButton` / choice popup (FR-155) | User CR-1.0b |
| C21 | CR-1.2 | **One snackbar at a time** through one feedback service; repeats dropped, priority for order outcomes (FR-156, FR-157) | User CR-1.2 |
| C22 | CR-1.11 | **Strings, images, icons from one place**, localisation-ready, `en` now, ready for `hi` etc. (§4.14, FR-160…FR-164; mechanism per ADR-0018, v1.5); §9 localisation row reworded | User CR-1.11 |
| C23 | CR-1.12 | **App icon and native splash** (§4.15, FR-170…FR-172); NFR-1…NFR-3 unchanged; NFR-22 keeps push/analytics init off the startup path | User CR-1.12 |
| C24 | CR-1.13 | **Failure-case table** §7a (F1…F18) and NFR-21: every row has an automated test | User CR-1.13 |
| C25 | CR-1.14 | **NFR-19** 100% line coverage of Dart code under `lib/` (app, `market_server`, `option_math`) with a closed exclusion list; **NFR-20** TDD | User CR-1.14 |
| C26 | CR-1.15 | **Deep links** (custom scheme + https) and **push placeholders** (FCM/APNs behind an interface, no keys) (§4.16, FR-175…FR-181); §1.2 and §9 push rows reworded | User CR-1.15 |
| C27 | CR-1.16 | **Generic analytics** interface, placeholder sinks, typed event catalogue (§4.17, FR-185…FR-189) | User CR-1.16 |
| C28 | CR-1.1, 1.3–1.10 | Engineering rules referenced in §5.3 (ER-1…ER-10, owned by the architect) and NFR-24; NFR-18 amended (application layer, gen_l10n allowed if the ADR picks it; superseded by C30) | User CR-1 |
| C29 | — | §9: landscape allowed for the full-screen chart only; §8 milestone **M-E** added; §12 recount: **142 FRs** (Must 111, Should 25, Could 6), **24 NFRs** | Product manager |

> All prices, orders, funds and AI answers are **simulated** on the local Dart market server.
> StockPulse is a practice app; nothing in it is investment advice.

---

## 0b. Change log v1.3

| # | Change | Driven by |
|---|---|---|
| C17 | §12 recount: **80 Must** (not 79), 96 FRs total. FR-116 was missed because a pipe character inside its code span split the table row; row text fixed | Scrum master |
| C18 | AI card footer wording fixed to **"Simulated. Not advice."** everywhere (FR-62, J-4); matches 03-ux-spec and 03b | dev-ai |

## 0a. Change log v1.2

| # | Change | Driven by |
|---|---|---|
| C16 | FR-28 (PCR / max pain on the chain header, Could) **deferred to v2.1**: Could priority, no Must depends on it, avoids a new `ChainView` wire field; PCR stays in the AI chain-snippet card | Architect LLD review D13 |

## 0. Change log v1.1

| # | Change | Driven by |
|---|---|---|
| C1 | Stale rule rewritten (§3.1): server-adjusted clock, `asOf` = last server confirmation (keep-alive ≤ 2 s), stale when age **> 5.0 s** | QA H1, Architect H2 |
| C2 | Market clock (§3.2): virtual server clock with `jumpTo`, exact phase boundaries, `demo` default mode, holiday list | Architect H3, QA H5 |
| C3 | Strike count fixed at **41 (±20)**; chain uses a `chain` socket channel, not per-contract subscriptions; fixed strike set per day | Architect H1 |
| C4 | Expiry settlement FR-49 (cash-settle at intrinsic, 15:30 on expiry day) | Architect H4 |
| C5 | Lazy tabs + visibility-based unsubscribe made explicit (FR-82, FR-86) | Architect H5 |
| C6 | Order submit safety: stale after Confirm, retry after timeout, reconnect and kill during submit (FR-31, FR-38, FR-38a) | QA H3, H4 |
| C7 | Resync rule (FR-84) and alert dedupe by `alertId` (FR-55); resync reloads orders, positions and alerts | QA H6, H7, Architect |
| C8 | New Must test hooks FR-120…FR-126 (injectable clock, per-symbol freeze, REST faults, subscription counts, trace marks, fake haptics) | QA §7 |
| C9 | Server grows to **50 simulated equities** + NIFTY index; quote cap per session raised to 100; instrument `kind` (index/equity/option) | Architect M |
| C10 | Option price band, funds rules, positions keyed by (symbol, product) (FR-34, FR-39, FR-41) | Architect M |
| C11 | AI chat transport = **HTTP NDJSON** (FR-67) | Architect §3.3 |
| C12 | UX answers: swipe dropped, block at Confirm, last-viewed underlying, context summary card, "Not now" on notice, no extra grace, banner queue | UX Q1–Q8 |
| C13 | Navigation fixed to the UX spec's 5 tabs; "Required margin" row replaced by "Funds available"; Buy blue / Sell red accepted | Design system |
| C14 | NFR measurement rules: device, runs, pass rule, 90/120 Hz, growth limit, golden setup (§5) | QA §3 |
| C15 | Reference device proposal, marked **needs user confirmation at Gate 1** (§5.1) | QA Q1 |

---

## 1. Overview

StockPulse v2 grows the v1 practice app (watchlist, stock page, market/limit orders, positions, Socket Lab)
into a mobile-first trading app for Indian retail equity and F&O traders: option chain, F&O orders with product
types, holdings and P&L summary, streamed price alerts, AI chat answering with live cards, payoff diagram,
cache-first instant start with stale-price safety, and a haptics platform channel. Every JD item J1–J10 maps to
at least one requirement.

### 1.1 Goals

| # | Goal | Measured by |
|---|---|---|
| G1 | Show what is true **now** and how fresh it is | 100% of price widgets carry `asOf`; stale rule §3.1 tested (NFR-7) |
| G2 | Act in ≤ 3 taps with one thumb | Options tab → cell → Buy → Confirm = 3 taps (J-2) |
| G3 | Start near-instantly | Cached content < 1 s on the reference device (NFR-2) |
| G4 | Stay smooth at the 09:15 load | 60 fps on a ticking 50-row watchlist and 41-strike chain (NFR-4, NFR-5) |
| G5 | Make F&O risk visible | Risk notice, ₹ totals, max loss on payoff, nudges |
| G6 | Prove it with numbers | Startup and frame measurements published in the docs (NFR-15) |

### 1.2 Non-goals

| Non-goal | Why |
|---|---|
| No real broker, exchange feed or order routing | Practice app; all data from `market_server/` |
| No real money, funds transfer or margin engine | Demo funds ₹10,00,000; margin not simulated (labelled) |
| No login, signup, KYC or user accounts | Single demo user with the v1 demo token |
| No real LLM or API key | AI chat is rule-based on the server (intake §5) |
| No real OS push delivery (APNs/FCM) | Alerts arrive over the socket while the app runs. v1.4: a `PushService` interface with no-op and placeholder FCM/APNs adapters exists (FR-179…FR-181); no keys, no server sends pushes |

---

## 2. Personas (from brief §2)

| Persona | One line |
|---|---|
| **Arjun**, options intraday | Lives in the NIFTY chain at 09:15 on mobile data; needs ATM pinned, buy/sell from the row, haptic on fill |
| **Meera**, swing/positional | Wi-Fi, 3–5 opens a day; needs instant start, clear day vs total P&L, alert → order in 2 taps |
| **Rohan**, new F&O learner | Budget Android, battery saver; needs plain-language AI cards, ₹ cost and max loss before he buys |

---

## 3. Decisions on the analyst's open questions

| ID | Question | Decision | Reason |
|---|---|---|---|
| D-1 | Underlyings and expiries | **NIFTY** index options, nearest **2 weekly** (Tuesday) expiries; **RELIANCE** and **HDFCBANK** stock options, nearest **2 monthly** expiries. BANKNIFTY and futures → backlog | One index + two stocks covers weekly and monthly calendars and both lot-size kinds without multiplying pricing work |
| D-2 | SL / SL-M | **SL in scope (Should)** for equity and options; **SL-M out** | SL shows trigger validation; SL-M is restricted for options and adds a second trigger path |
| D-3 | Multi-leg | **Single-leg orders only**; strategy builder shows a **multi-leg payoff preview** (≤ 4 legs, view only); each leg has "Trade" opening a prefilled single-leg sheet | Delivers the payoff diagram (J4) without basket/atomic-order complexity |
| D-4 | Stale quote and orders | **Block**: Confirm disabled with the reason; no warn-and-allow. The block applies to the **traded instrument's own quote** (§3.1) | Trading on a wrong price is the worst failure (R1); blocking is simple to test |
| D-5 | Market clock | **Virtual clock on the server** (§3.2): Pre-open, Open, Closed, MIS square-off 15:20, settlement 15:30 on expiry, T+1 roll at day change; debug endpoint sets an exact time | Pre-open, expiry and square-off moments cannot be demoed if the market is always open |
| D-6 | AI card actions | Cards **may have action buttons** (Open chain, Trade this strike, Set alert, View payoff) that **open a screen prefilled**; the user confirms; **chat never places an order** | Useful chat (M8) while a human confirms every trade |
| D-7 | Risk notice and nudges | **One-time F&O risk notice** before the first F&O order sheet ("Not now" allowed, notice returns next time); stored locally, labelled simulation. **Soft nudges** (do not block): limit > 3% from LTP, order value > 25% of demo funds, option expiring today, underlying quote stale | Mirrors SEBI-style disclosure and Kite-style nudges at low cost; only stale data on the traded contract hard-blocks |

### 3.1 Stale rule (normative; used by FR-5, FR-81, FR-90…FR-95, FR-38, NFR-7, NFR-8)

| Item | Rule |
|---|---|
| `asOf` | Server time (ms, UTC) at which the server **last confirmed** the value, not the last trade time. Stamped on every flush; for unchanged subscribed instruments the server re-confirms at least every **2 s** (keep-alive). A quiet deep-OTM strike therefore stays live while the server and socket are healthy |
| Server-now on the client | `serverNow = deviceNow + offset`; offset is set from `serverTime` in the `welcome` frame and refreshed on every `pong` (half round-trip corrected). Device clock skew does not change results |
| Age | `age = serverNow − asOf` |
| Live | Socket status `live` **and** (phase is Open → `age ≤ 5.0 s`) |
| Stale | Socket not `live`, **or** phase Open and `age > 5.0 s` (5.0 s exactly is live), **or** a cached value that has not had a live frame since start |
| Closed | Phase Pre-open or Closed: shown as "Closed · as of hh:mm:ss" / "Pre-open · IEP", normal colours, not stale; orders follow FR-37 |
| Order block | Confirm is disabled when the **traded instrument** is stale. A stale underlying with a live contract shows a nudge, not a block (the order price is the premium; a socket-level problem stales both anyway) |
| Evaluation | Re-evaluated on every frame and on a 250 ms client timer, so a freeze is detected within 5.25 s |

### 3.2 Market clock (normative; FR-14, FR-37, FR-43, FR-44, FR-46, FR-49, FR-111, FR-116)

| Item | Rule |
|---|---|
| Clock | One server `MarketClock` = wall time + offset, with `jumpTo(t)`; injected into engine, broker, alerts, expiry calendar, gateway. Client uses an injectable `Clock` (FR-120) |
| Phases (IST, Mon–Fri, non-holiday) | Pre-open **[09:00:00.000, 09:15:00.000)** · Open **[09:15:00.000, 15:30:00.000)** · Closed otherwise. Boundaries: start inclusive, end exclusive |
| Square-off | MIS square-off runs at the first tick **≥ 15:20:00.000** |
| Settlement | Expiring contracts settle at **15:30:00.000** on expiry day (FR-49) |
| Day roll | At 09:00 of the next trading day: T+1 roll, new `prevClose`, expired contracts removed, next far expiry listed |
| Expiry calendar | NIFTY weekly Tuesday; monthly = last Tuesday; stock options monthly. If Tuesday is a holiday, expiry = previous trading day. A **holiday list** lives in one config table with a source date; tests inject their own |
| Modes | `--clock=demo` (**default** for dev and profile builds): virtual time starts at 10:00:00 IST on the current date (or the next trading day) so the market is Open whenever a demo runs; "Demo clock" chip shown. `--clock=real`: IST wall time |
| Pre-open behaviour | Equities show an **indicative price (IEP)** that drifts slowly; options show previous close, frozen. Equity **limit** orders are accepted and queued; at 09:15:00 they fill if the open price crosses the limit. Market orders and all option orders are disabled with a reason |
| Closed | Engine stops ticking; all orders rejected with code `market_closed` |

---

## 4. Functional requirements

Priority **M**/**S**/**C**. "v1 ✅" = already satisfied; keep it and add the missing tests. Acceptance: G (given) · W (when) · T (then).

### 4.1 Instruments and watchlist

| ID | Requirement | P | v1 | Acceptance |
|---|---|---|---|---|
| FR-1 | Live watchlist with LTP, change, change % | M | ✅ | G 50 rows · W one tick on A · T row A built once, other rows 0 builds (build counter) |
| FR-2 | Up/down text colour by change vs prev close (static, no flash) + ▲/▼ and sign | M | ✅ | G LTP > prev close · T `up` colour, ▲, "+" |
| FR-3 | Default list includes NIFTY, RELIANCE, HDFCBANK | M | | G fresh install · T those three visible |
| FR-4 | Long-press or `⋮` on a row → Buy / Sell / Chart / Option chain / Set alert. **No swipe actions** | S | | G RELIANCE row · W long-press · T sheet with 5 actions; G NIFTY · T Chart / Option chain / Set alert only |
| FR-5 | Row shows stale style when its quote is stale (§3.1) | M | | G socket live, RELIANCE frozen (FR-121) · W 5.1 s · T only RELIANCE row stale with "as of"; G socket down · T all rows stale at once |
| FR-6 | Instrument metadata has `kind` (index/equity/option), lot size, tick size, band, expiry, strike. Indices have no Buy/Sell and no depth | M | | G NIFTY page · T no Buy/Sell buttons, no depth panel |
| FR-7 | Server simulates **50 equities** (NIFTY 50 names) + NIFTY index; quote subscription cap per session 100 | M | | G server start · T `/instruments` lists 50 equities + 1 index |

### 4.2 Stock page

| ID | Requirement | P | v1 | Acceptance |
|---|---|---|---|---|
| FR-10 | Chart 1D–5Y, 6 intervals, 5 types, live last candle | M | ✅ | G 1D candles · W tick · T last candle updates |
| FR-11 | Market depth and stats (equities) | M | ✅ | G RELIANCE · T 5-level depth |
| FR-12 | Buy (blue) / Sell (red) in a sticky bottom bar; stay enabled when stale/closed, blocking happens at Confirm | M | | G 360×800 · T rects inside bottom 25% and ≥ 48×48 dp |
| FR-13 | "Option chain" entry for underlyings with options | M | | G RELIANCE · W tap · T chain on nearest expiry |
| FR-14 | Market status chip (Pre-open / Open / Closed / Demo clock) | M | | G clock 09:10 · T "Pre-open" |

### 4.3 Option chain

| ID | Requirement | P | v1 | Acceptance |
|---|---|---|---|---|
| FR-20 | Chain of **41 strikes (ATM ±20)**, fixed per expiry per trading day (rows keyed by strike, ATM is a highlight, never a re-index); calls left, strike centre, puts right | M | | G NIFTY · T 41 rows; W spot moves 3 strikes · T row set unchanged |
| FR-21 | Default columns LTP, OI (lakhs + bar), ΔOI; column picker adds IV (1 dp), delta | M | | G picker · W enable IV · T IV column |
| FR-22 | ATM centred (~55% height) on open and expiry change; "Back to ATM" button when ATM leaves the viewport | M | | G scrolled 10 rows · W tap · T ATM centred |
| FR-23 | ATM highlight moves when spot crosses a strike midpoint; ITM shaded; the list never auto-scrolls | M | | G offset X · W ATM moves 2 strikes · T `ScrollController.offset` = X (±0 px) |
| FR-24 | Expiry picker with D-1 expiries; "Expires today" badge; holiday rule (§3.2) | M | | G Tuesday is a fixture holiday · T expiry Monday, badge on Monday |
| FR-25 | Underlying LTP live in the header | M | | G tick · T header updates |
| FR-26 | Tap a cell → Buy/Sell → order sheet prefilled (contract, side, product NRML, 1 lot) | M | | G ATM CE · W Buy · T sheet with contract and 1 lot |
| FR-27 | Greeks (Δ Γ Θ Vega) on a strike sheet; maths in a shared pure-Dart `option_math` package | S | | G long-press strike · T greeks shown |
| FR-28 | PCR and max-pain header stats — **deferred to v2.1** (v1.2, C16); PCR still appears in the AI chain card | C | | G chain · T PCR shown |
| FR-29 | "Add to strategy" from a cell | S | | G 2 cells added · T builder shows 2 legs |
| FR-29a | Chain data via one `chain` socket subscription (underlying + expiry + strike range + fields), compact per-strike deltas; does not count against the quote cap | M | | G chain open · T server subscription count shows 1 chain sub, 0 extra quote subs |
| FR-29b | Options tab opens the **last viewed** underlying; first run has no implicit selection and prompts the trader to choose one | S | | G last viewed RELIANCE · W reopen tab · T RELIANCE chain; G no saved choice · T chooser, no chain request until selection |
| FR-29c | Expired contract while chain is open: "Expired" shown, picker moves to the next expiry | M | | G expiring chain open · W debug next day · T moved within 1 s |

### 4.4 Order entry (equity + F&O)

| ID | Requirement | P | v1 | Acceptance |
|---|---|---|---|---|
| FR-30 | Bottom sheet, Market and Limit; errors shown over the sheet | M | ✅ | G rejection · T error above sheet |
| FR-31 | Idempotent order key; one in-flight submit; client retries a timed-out POST with the **same key** (max 2 retries) | M | ✅ partly | G 2 taps 50 ms apart · T exactly 1 POST. G server stores order then drops the ack (FR-122) · W retry · T 1 order on server, 1 fill notice, 1 haptic |
| FR-31a | While the outcome is unknown the sheet shows "Placing… checking status", Confirm locked. After retries fail: sheet closes, snack "Order status unknown · see Orders", order shown **Pending** until resync gives the final state. App killed with an order in flight: on relaunch `GET /orders` shows the truth; **never auto-resubmit**. Pending rows offer **Refresh status** only (no Retry): it is a REST `GET /orders/{id}`, **enabled while the socket is Reconnecting** (REST may still work), **disabled with "Waiting for connection" only when the app is Offline** (no network); resync refreshes Pending rows automatically | M | | G kill during POST · W relaunch · T order list matches server; 0 new POSTs |
| FR-32 | Product: equity **MIS / CNC** (default CNC), F&O **MIS / NRML** (default NRML) | M | | G option · T only MIS/NRML offered |
| FR-33 | F&O quantity in **lots**; shows units = lots × lot size and **₹ order value**; lot size from metadata only | M | | G fixture lot size 50 · W 2 lots @ ₹100 · T "100 qty · ₹10,000" |
| FR-34 | Tick size ₹0.05; price band from metadata: equities ±20% of prev close; options **₹0.05 to 3× prev close**; client and server validate and show the range | M | | G equity prev close 100, limit 120.05 · T server `price_band`, "Outside price band 80.00–120.00"; G limit 101.03 · T "Price must be a multiple of 0.05" |
| FR-35 | SL: trigger + limit; buy trigger ≤ limit, sell trigger ≥ limit | S | | G sell SL trigger < limit · T inline error |
| FR-36 | Nudges per D-7 (soft, dismissible) | S | | G limit 4% from LTP · T nudge, Confirm enabled |
| FR-37 | Phase rules (§3.2): Pre-open → equity limit only (queued), market and option orders disabled; Closed → `market_closed` | M | | G 09:14:59.900 + option · T disabled "Options open at 09:15"; G 09:15:00.000 · T enabled without reopening; G Closed · T server `market_closed`, text over sheet |
| FR-38 | Confirm disabled with reason while the traded instrument is stale; inputs kept | M | | G sheet open, live · W freeze, tap Confirm at 5.1 s · T 0 POSTs, "Price not live since hh:mm:ss" |
| FR-38a | Stale **after** a POST is sent does not cancel it; its final status is shown when known | M | | G POST in flight · W freeze · T no client cancel; final status shown after resync |
| FR-39 | Demo funds ₹10,00,000. Buy debits on fill, sell credits on fill; open orders block nothing; buy rejected `insufficient_funds` if order value > funds at placement; short option sells allowed, labelled "Margin not simulated"; sheet shows "Funds available" | S | | G funds ₹5,000, buy ₹13,000 · T `insufficient_funds` |
| FR-39a | CNC sell above held quantity rejected `insufficient_holdings` | M | | G hold 10 · W sell 11 CNC · T rejected |

### 4.5 Positions, holdings, P&L summary

| ID | Requirement | P | v1 | Acceptance |
|---|---|---|---|---|
| FR-40 | Positions with live P&L | M | ✅ | G open position · W tick · T P&L updates |
| FR-41 | Positions keyed by **(symbol, product)**; F&O rows show product and lots | M | | G MIS and CNC buys of RELIANCE · T two rows, not netted |
| FR-42 | Exit → prefilled opposite-side sheet with full quantity | M | | G long 2 lots · W Exit · T sell 2 lots prefilled |
| FR-43 | MIS rows "Auto square-off 15:20"; expiring rows "Expires today" | M | | G MIS at 14:00 · T badge |
| FR-44 | Server squares off MIS at ≥ 15:20:00.000 at market and sends order updates | S | | G clock 15:19:59 → 15:20:00 · T MIS closed, CNC/NRML untouched, notice shown |
| FR-45 | Holdings: qty, avg, LTP, **Day** P&L, **Total** P&L | M | | G holding · T both labelled |
| FR-46 | T+1 roll: CNC buys move to holdings at day roll | S | | G CNC buy · W debug next day · T in holdings |
| FR-47 | Summary card follows the selected tab: Holdings → invested, current, Day, Total; Positions → realised + unrealised today; demo funds on both | M | | G 3 holdings · T sums match rows |
| FR-48 | Positions / Holdings / Orders tabs in Portfolio | M | | G portfolio · T three tabs |
| FR-49 | Expiry settlement: at 15:30:00.000 on expiry day, open option positions cash-settle at intrinsic value, move to realised P&L, funds updated, `settlement` frame sent | M | | G long CE strike 24500, spot 24600, 1 lot of 65 · W 15:30 · T settled ₹6,500, position closed |

### 4.6 Alerts

| ID | Requirement | P | v1 | Acceptance |
|---|---|---|---|---|
| FR-50 | Create price alert (above/below) on any instrument; stored on server | M | | G RELIANCE ≥ 1500 · T listed |
| FR-51 | Server sends `alert.triggered` with `alertId` + `triggeredAt` on the session's socket; one-shot | M | | G cross · T one frame; status triggered |
| FR-52 | In-app banner; tap → stock page. If an order sheet is open, banner is **queued** until it closes and the bell shows a dot | M | | G banner · W tap · T stock page; G sheet open · T no banner until close |
| FR-53 | Alerts list with delete and status | S | | G 2 alerts · W delete · T 1 left |
| FR-54 | Alerts triggered while disconnected are delivered after reconnect (resync `GET /alerts`) | M | | G socket down during cross · W reconnect · T banner shown |
| FR-55 | Client shows **one banner per `alertId`** (persisted seen-set), even if delivered live and again by resync | M | | G same alertId live + resync · T 1 banner |

### 4.7 AI chat with live cards

| ID | Requirement | P | v1 | Acceptance |
|---|---|---|---|---|
| FR-60 | Chat screen; answers stream as typed, versioned cards (text, quote, chart, chain snippet, payoff, table, fallback, error); unknown type → text fallback | M | | G question · T first card painted before the stream ends |
| FR-61 | Intents: quote, compare, "what does the chain say", payoff of a strategy, top movers, explain a term | M | | G "explain theta" · T text card |
| FR-62 | Every card footer, exact text **"Simulated. Not advice."** (caption, never truncated; matches UX spec and design system) | M | | G any card · T label present |
| FR-63 | Live cards carry instrument ids and subscribe through the normal quote path when ≥ 50% visible; card prices obey §3.1 | M | | G card scrolled off · T server sub count for that symbol drops within 1 s (ref-counted) |
| FR-64 | Action buttons open prefilled screens tagged "From AI chat"; never submit; stale handled by the sheet | M | | G "Trade this strike" · T sheet prefilled, 0 POSTs |
| FR-65 | Suggestion chips; unknown questions get a fallback with chips | M | | G gibberish · T fallback + chips |
| FR-66 | History for the session only, capped at 50 answers | C | | G kill app · T cleared |
| FR-67 | Transport: `POST /api/v1/ai/ask` returning **NDJSON** (one card per line); cancel = close request; mid-stream error keeps received cards and adds an error card | M | | G server error after card 2 · T cards 1–2 + "Answer interrupted · Retry" |

### 4.8 Charts and payoff

| ID | Requirement | P | v1 | Acceptance |
|---|---|---|---|---|
| FR-70 | Single-leg payoff at expiry from the order sheet | M | | G buy CE · T hockey-stick chart |
| FR-71 | Strategy builder ≤ 4 legs; payoff at expiry + today line (`option_math`) | M | | G straddle · T V shape |
| FR-72 | Max profit, max loss (or "Unlimited"), breakevens, net premium in ₹ | M | | G long CE · T max loss = premium × units |
| FR-73 | Crosshair drag (alt: tap a point) shows P&L at a spot; readable on 360 dp | S | | G drag · T label follows |

### 4.8a Advanced stock chart (v1.4, CR-1.0; basis `team/reviews/kite-chart-study.md`)

Applies to the stock/index page chart (FR-10). Indicator maths is pure Dart with fixture tests; every price on the
chart and readout obeys §3.1. Limits: **at most 4 active studies** (overlays + panes) and **at most 2 lower panes**
per chart; **at most 20 drawings per symbol**. Defaults below are editable in the study's settings via `SpPicker`
(FR-155) or a number stepper.

| ID | Requirement | P | Acceptance |
|---|---|---|---|
| FR-130 | Studies sheet from a chart toolbar button: list of available studies, add, edit parameters, remove (✕ on the study chip); 5th study refused with "Up to 4 studies" | M | G 4 studies active · W add a 5th · T refused with the message, 4 remain |
| FR-131 | **SMA(N)** overlay, default 20, N 2–200 | M | G fixture of 60 closes · T values equal the reference table to 2 dp; first N−1 points not drawn |
| FR-132 | **EMA(N)** overlay, default 9 (seed = SMA of first N) | M | G fixture · T values equal the reference table to 2 dp |
| FR-133 | **VWAP** overlay on intraday intervals only, reset at each session open 09:15 IST; on 1d/1w hidden with chip "VWAP: intraday only" | M | G 1D 5m · T value at the 3rd candle = Σ(typical × vol)/Σvol of candles 1–3; G 1Y 1d · T chip shown, no line |
| FR-134 | **RSI(14)** in a lower pane, Wilder smoothing, 0–100 axis, 30/70 guide lines | M | G fixture · T values equal the reference table to 2 dp; pane height ≥ 64 dp at 360×800 |
| FR-135 | **Bollinger Bands** (20, 2σ population stdev) overlay | S | G fixture · T upper/mid/lower equal the reference to 2 dp |
| FR-136 | **MACD** (12, 26, 9): line, signal, histogram in a lower pane | S | G fixture · T three series equal the reference to 2 dp; histogram up/down colours + shape cue |
| FR-137 | **Supertrend** (10, 3) overlay, colour flips with trend and a ▲/▼ marker at flips | C | G fixture · T flip candles match the reference |
| FR-138 | Indicator maths in a pure-Dart module, no Flutter imports; a live tick recomputes only the last value of each study (no full recompute) | M | G 500 candles, 4 studies · W 1 tick · T each study's update touches 1 index (counter in test) |
| FR-139 | **Readout row** above the plot: O, H, L, C, volume, change % for the crosshair candle, else the last candle; plus each active study's value. When the instrument is stale the last-candle readout shows "as of hh:mm:ss" | M | G crosshair on candle 10 · T readout equals candle 10 OHLCV and study values; G stale · T "as of" shown |
| FR-140 | **Horizontal line** drawing: place by tap in draw mode, drag to move, select → delete; price label on the axis | M | G draw mode · W tap at ₹1,500 · T line at 1,500.00 (snapped to tick 0.05); W delete · T gone |
| FR-141 | **Trend line** drawing: two handles, drag either handle or the line; handles ≥ 44 dp touch area | M | G two taps · T line between both (time, price) points; W drag handle · T only that end moves |
| FR-142 | **Fibonacci retracement**: two points, levels 0, 23.6, 38.2, 50, 61.8, 100 % with prices | S | G points 100 → 200 · T 61.8 % level at 161.80 |
| FR-143 | Studies, parameters and drawings **saved locally per symbol**; drawings anchored to (time, price) so they survive range, interval and type changes and app restart; "Reset demo account" (FR-112) wipes them | M | G trend line on RELIANCE 1D · W switch to 1W, kill app, reopen · T line at the same (time, price); G reset · T none |
| FR-144 | **Full-screen landscape chart**: expand button on the chart (and rotating the device while on the chart) opens a landscape full-screen route; the rest of the app stays portrait; range, interval, type, studies, drawings and crosshair state kept both ways; exit button and system back return to portrait; connection badge and stale "as of" visible | M | G 1W 15m + RSI · W expand, then exit · T same state, 0 extra candle fetches |
| FR-145 | **Buy / Sell on the full-screen chart** (equities only) open the existing order ticket (FR-30…FR-39a, risk notice, stale block); in landscape it is a **right side sheet**, 400 dp wide, full height, chart visible (Q-UX-1, v1.5). No instant / one-tap orders | M | G full-screen RELIANCE · W Buy · T side sheet prefilled, chart still visible, Confirm still required; G NIFTY · T no Buy/Sell |
| FR-146 | Chart settings sheet: **log scale** (price axis) and **gridlines** on/off, saved | S | G log on, 5Y · T equal % moves have equal pixel heights (±1 px) |
| FR-147 | Last used range, interval and chart type remembered app-wide across restarts | S | G set 1M + line · W relaunch, open any stock · T 1M + line |
| FR-148 | **Set alert at a chart price**: from the crosshair readout or a horizontal line's menu, "Set alert at ₹X" opens the alert form prefilled (FR-50) | S | G crosshair at 1,512.35 · W Set alert · T form shows 1,512.35, direction from LTP |
| FR-149 | **Limit order at a chart price**: same menus offer "Buy/Sell limit at ₹X" → prefilled order sheet (Limit, price snapped to tick); never submits | S | G line at 1,480 · W Buy limit · T sheet Limit 1,480.00, 0 POSTs |
| FR-150 | **Hollow candles** chart type | C | G close > open · T hollow body; close < prev close · T down colour |
| FR-151 | **Compare** one other symbol as a % change line from the first visible candle, with its own legend | C | G RELIANCE + NIFTY · T both start at 0 % |
| FR-152 | **Previous / next symbol** arrows on the chart step through the current watchlist | C | G RELIANCE 3rd in list · W next · T 4th symbol's chart, same settings |

Later (v2.1 / backlog, per the study): Renko, Kagi, Line break, Point & Figure, range bars; extra intervals (3m, 10m,
30m, 2h, 4h, 1M); full indicator library and custom scripts; rectangles, channels, text and other drawings;
multi-chart and named layouts; order and position lines on the chart with drag-to-modify; market depth panel inside
the chart; GTT. **Rejected:** instant order placement (conflicts with D-4 and the Confirm rule).

### 4.9 Startup, offline, stale, resync

| ID | Requirement | P | v1 | Acceptance |
|---|---|---|---|---|
| FR-80 | Cache-first: one JSON snapshot file (`schemaVersion`, `savedAt`) with watchlist, positions, holdings; read started in `main()`, **not awaited before `runApp`** | M | | G airplane mode · W cold start · T cached lists painted |
| FR-81 | Cached prices stale with "as of" until their first live frame | M | | G cold start · T grey + time until tick |
| FR-82 | Tabs built on first visit only | M | | G after first frame · T no `OptionChainScreen` found; chain provider 0 listeners |
| FR-83 | Connection badge Live / Reconnecting / Offline | M | ✅ | G drop · T Reconnecting |
| FR-84 | Reconnect, resubscribe, gap resync. On a seq gap the client requests resync; no value from a frame with seq < snapshot seq is applied; resync reloads quotes, chain, **orders, positions, alerts** | M | ✅ partly | G skip-seq · T provider never holds an older value; fill and alert counts = 1 |
| FR-85 | Background: socket closed within 2 s, no reconnects while paused; resume on foreground | M | ✅ | G backgrounded (fake clock) · T closed ≤ 2 s, 0 reconnect attempts |
| FR-86 | Hidden tabs and covered routes cancel their price streams (visibility signal) and keep scroll position | M | | G chain pushed over watchlist · T watchlist quote subs released |
| FR-87 | Cache older than **7 days**, wrong schema or corrupt → deleted, network load, one crash-hook log, no crash | M | | G truncated JSON · T app starts, 1 log |
| FR-90 | Global stale banner when no frame for > 5 s while Open or socket not live > 5 s; disappears on first live frame | M | | G freeze 15 s · T banner "Prices not live since hh:mm:ss" |
| FR-91 | Per-instrument stale from `asOf` (§3.1); quiet instruments stay live through keep-alive | M | | G deep OTM strike no trades 60 s, socket healthy · T live; G RELIANCE frozen 5.1 s · T only RELIANCE stale |
| FR-92 | Sheet re-enables on the first live frame after stale | M | | G stale → live · T Confirm enabled, inputs kept |
| FR-93 | `asOf` on every quote, chain cell and card price; `serverTime` on `welcome` and `pong` | M | | G any price frame · T fields present |
| FR-94 | Client clock offset from `serverTime` (§3.1) | M | | G device clock +30 s · T stale results unchanged |
| FR-95 | Server keep-alive re-confirms unchanged subscribed values every ≤ 2 s | M | | G no price change 10 s · T `asOf` advances ≤ 2 s apart |

### 4.10 Platform channel

| ID | Requirement | P | v1 | Acceptance |
|---|---|---|---|---|
| FR-100 | `MethodChannel('stockpulse/haptics')` with `success` / `rejection` (Android `performHapticFeedback`/`VibrationEffect`, iOS feedback generators); keyed on (orderId, status) transition | M | | G fill delivered live and by resync · T fake channel gets 1 `success` |
| FR-101 | `MissingPluginException` / no hardware → silent no-op, logged once | M | | G macOS · T no crash |
| FR-102 | Haptics toggle in Settings | S | | G off · W fill · T 0 calls |

### 4.11 Settings and debug

| ID | Requirement | P | v1 | Acceptance |
|---|---|---|---|---|
| FR-110 | Socket Lab (raw frames capped at 500, drop / freeze / skip-seq) under More | M | ✅ | G Lab · W drop · T reconnect seen |
| FR-111 | Debug clock: set exact time, presets (09:14:50, 15:19:50, 15:29:50, next day), "Demo clock" chip while overridden | M | | G set Closed · T chip + order rules change |
| FR-112 | Reset demo account = server reset + local wipe (risk-notice ack, alert seen-set, cache) | S | | G reset · T ₹10,00,000, empty lists, notice shows again |
| FR-113 | One-time F&O risk notice (D-7), "I understand" / "Not now", re-viewable in More | M | | G first F&O sheet · T notice; after ack · T not again |
| FR-114 | Debug overlay: startup timings and FPS (debug/profile only) | S | | G overlay on · T timings shown |
| FR-116 | Server flag `--clock=demo` or `--clock=real`, default `demo` (§3.2) | M | | G default start at 20:00 IST · T phase Open, "Demo clock" chip |

### 4.12 Test hooks (Must; no test of a safety rule without them)

| ID | Requirement | P | Acceptance |
|---|---|---|---|
| FR-120 | Injectable `Clock` on server (engine, broker, alerts, calendar, gateway) and client (stale rule, timers) | M | G fake clock advanced 5.1 s · T stale without real waiting |
| FR-121 | Per-symbol freeze: `POST /debug/freeze?symbol=X&seconds=N` (socket-wide freeze kept) | M | G freeze RELIANCE · T other symbols keep ticking |
| FR-122 | REST fault injection: `POST /debug/faults` {delayMs, status 5xx, dropAckAfterStore, path} for the next N requests | M | G dropAckAfterStore on /orders · T order stored, client times out |
| FR-123 | `POST /debug/clock` {time} and `GET /clock` | M | G set 15:20:00 · T square-off runs |
| FR-124 | `GET /debug/subscriptions` → counts per session and channel | M | G background · T 0 subs |
| FR-125 | Timeline marks: `cache_painted`, `first_live_tick_painted`, `frame_received(seq)`, `price_painted(seq)` | M | G profile trace · T marks present |
| FR-126 | Fake haptics channel handler for tests | M | G fill · T 1 recorded call |

### 4.13 Shared feedback and pickers (v1.4, CR-1.0b, CR-1.2)

| ID | Requirement | P | Acceptance |
|---|---|---|---|
| FR-155 | **`SpPicker`** designed component (bottom-sheet list or segmented chips per 03b) replaces every `DropdownButton`, `DropdownMenu` and choice `PopupMenuButton`: chart type, interval, study parameters, order type, product, chain columns, alert direction. Rows ≥ 48 dp, selected tick, semantics "selected" | M | G app source · T 0 uses of `DropdownButton`/`DropdownMenu` under `lib/` (CI check); G picker open · T golden matches and `androidTapTargetGuideline` passes |
| FR-156 | **One snackbar at a time** through a single feedback service (ADR-0019); no widget calls `ScaffoldMessenger.showSnackBar` directly. A message with the same key as the one visible (or shown < 4 s ago) is dropped; a different message of equal or higher priority replaces the visible one; a lower one waits in one slot (FR-157), never more. A disabled action is a state, not an event: it shows its inline reason + haptic, no snackbar (UX 12.1) — v1.5 | M | G a disabled Confirm tapped 5 times in 1 s · T 0 snackbars, reason line focused; G an order rejected 5 times in a row (same key) · T exactly 1 snackbar, waiting slot empty; G message A then B (same priority) · T only B visible |
| FR-157 | Snackbar priority: **order outcome** (fill, rejection after close, status unknown, settlement, square-off) > **error** > **info**. A lower-priority message never replaces a higher one; it goes to **one waiting slot** (newest wins, the older waiting message is discarded) and shows with a fresh timer when the higher one closes. Equal or higher priority replaces at once (ADR-0019 v2.1) — v1.5 | M | G fill snack visible · W info A, then info B · T fill stays; after it closes B shows, A never shows; G error visible · W fill · T fill replaces it at once; G any sequence · T ≤ 1 snackbar on screen, ≤ 1 waiting |

### 4.14 Strings, images and icons in one place (v1.4, CR-1.11)

| ID | Requirement | P | Acceptance |
|---|---|---|---|
| FR-160 | All user-facing text lives in **one localisation-ready place** per locale (`en_IN` now), read by widgets and by application controllers through one API; the mechanism is the architect's (ADR-0018: hand-written `AppStrings` interfaces + one implementation per locale, no ARB / gen_l10n, no codegen) — v1.5. No user-facing string literals in presentation code (symbols, numbers and debug-only Socket Lab frames exempt) | M | G CI string-literal check on `features/**/presentation` and `core/widgets` · T 0 findings |
| FR-161 | Placeholders and plurals are part of the string API (typed parameters, plural rules from `intl`; ADR-0018), for example lots, orders count; no string concatenation for sentences — v1.5 | M | G 1 lot / 2 lots · T "1 lot" / "2 lots" from one string member |
| FR-162 | Numbers, ₹ amounts (lakh/crore grouping), percentages, dates and times formatted by one formatter keyed on the locale (`en_IN` now) | M | G 1234567.5 · T "₹12,34,567.50"; no `NumberFormat` / `DateFormat` constructed outside the formatter (CI check) |
| FR-163 | Images and icons come from one registry (`AppAssets`, `AppIcons`); no raw asset paths or `Icons.*` outside it; swapping an icon is a one-line change | M | G CI check · T 0 `Icons.` or `'assets/` uses outside the registry |
| FR-164 | Locale readiness: a pseudo-locale (text +40 %, accented) runs in debug; an unsupported device locale falls back to English; a locale missing a string does not compile; adding Hindi = one set of Hindi string tables + register the locale, no screen or controller change (ADR-0018) — v1.5 | S | G pseudo-locale, 360×800 · T no overflow on watchlist, chain, order sheet, portfolio |

### 4.15 App icon and splash (v1.4, CR-1.12)

| ID | Requirement | P | Acceptance |
|---|---|---|---|
| FR-170 | App icon from one 1024 px master (ui-designer): Android adaptive icon (foreground, background, **monochrome** for themed icons) and all iOS sizes, no alpha on iOS | M | G release builds · T launcher shows the icon; iOS asset catalog builds with 0 warnings; Android themed icon shows the monochrome layer |
| FR-171 | **Native splash only**: Android 12+ SplashScreen API (and launch theme below 12), iOS LaunchScreen storyboard; brand background + centred mark; removed at the first Flutter frame; no Flutter-drawn splash route and no artificial delay | M | G cold start · T first Flutter route is the shell with cached watchlist (FR-80); NFR-1…NFR-3 still pass |
| FR-172 | Splash and icon background follow system light/dark | S | G dark mode · T dark splash background |

### 4.16 Deep links and push placeholders (v1.4, CR-1.15)

Schemes: custom `stockpulse://<path>` and https `https://stockpulse.example/app/<path>` (placeholder host; App Links
`assetlinks.json` and `apple-app-site-association` templates kept in the repo, not deployed). Both map to the same
go_router path.

| Path | Opens |
|---|---|
| `/watchlist` | Watchlist tab |
| `/stock/{symbol}?range=&interval=` | Stock or index page (chart at the given range/interval if valid) |
| `/stock/{symbol}/chart` | Full-screen chart (FR-144) |
| `/options/{underlying}?expiry=YYYY-MM-DD` | Option chain (nearest expiry if missing or expired) |
| `/trade/{symbol}?side=&type=&price=` | Stock page with the order sheet prefilled (side buy or sell, type market or limit; never submitted) |
| `/portfolio/{tab}` | Portfolio sub-tab (positions, holdings or orders) |
| `/orders/{orderId}` | Orders tab, row highlighted |
| `/alerts`, `/alerts/new?symbol=&price=` | Alerts list / prefilled alert form |
| `/ai?q=` | AI chat with the question prefilled, not sent |

| ID | Requirement | P | Acceptance |
|---|---|---|---|
| FR-175 | go_router route table is the single source of screen paths; every path above is a route; both schemes resolve to it | M | G `stockpulse://stock/RELIANCE` and `https://stockpulse.example/app/stock/RELIANCE` · T same route and screen |
| FR-176 | Links work on cold start, warm resume and in foreground; the back stack is built so Back goes to the tab root (stock page → Watchlist, chain → Options root) | M | G cold start with `/options/NIFTY` · W back · T Options tab root, app not closed |
| FR-177 | Invalid link (unknown path, unknown symbol, bad params, expired expiry) opens the nearest valid screen with one snackbar "Link not available"; never a crash or blank screen | M | G `/stock/XYZ` · T Watchlist + 1 snackbar; G expired expiry · T nearest expiry |
| FR-178 | Link safety: links never submit, confirm, cancel or modify orders, never change settings or reset; trade links open a sheet that needs Confirm and still show the risk notice and stale block; debug screens (Socket Lab, clock) not reachable by link in release builds | M | G `/trade/RELIANCE?side=buy` · T 0 POSTs; G release build, `/more/socket-lab` · T treated as invalid (FR-177) |
| FR-179 | `PushService` interface (init, permission status/request, token stream, foreground message stream, opened-message stream, initial message) with a **no-op default**; FCM and APNs adapters are placeholders behind it; no keys, `google-services.json` or `GoogleService-Info.plist` committed; app builds and runs without Firebase | M | G clean checkout · T debug and release builds succeed with the no-op service; secret scan finds 0 push keys |
| FR-180 | Push payload contract `{type, id, link}` with type one of alert, order, system; tapping a notification routes through the deep-link handler (FR-176); alert pushes dedupe with the `alertId` seen-set (FR-55) | M | G fake service emits opened alert with `link=/stock/RELIANCE` · T stock page; same `alertId` already seen · T no second banner |
| FR-181 | Notification permission asked in context (first alert created), never at launch; denied → in-app alerts unchanged; Settings shows the status | S | G first launch · T no permission prompt; G denied · T alert still shows the in-app banner |

### 4.17 Analytics (v1.4, CR-1.16)

| ID | Requirement | P | Acceptance |
|---|---|---|---|
| FR-185 | `Analytics` interface (`logEvent`, `setScreen`, `setUserProperty`, `reset`) with a fan-out to N sinks; default sinks: debug-log (debug builds) and no-op (release). Adding a provider = one sink class + one registration line, no feature code change | M | G test registers a fake sink · W J-2 run · T fake sink receives the J-2 events in order |
| FR-186 | One typed event catalogue: names `snake_case` ≤ 40 chars, ≤ 25 params, values string/num/bool only; features log only catalogue events | M | G catalogue unit test · T every event passes the rules; no raw event name strings outside the catalogue (CI check) |
| FR-187 | Key events: `app_open` (cold/warm, ms to first frame), `screen_view`, `watchlist_row_action`, `chart_opened`, `chart_setting_changed` (range/interval/type/log), `study_added`, `study_removed`, `drawing_added`, `chart_fullscreen`, `order_sheet_opened` (source: watchlist, chart, chain, ai, alert, deeplink, position), `order_confirm_tapped`, `order_result` (filled/rejected/unknown + code), `order_blocked_stale`, `risk_notice_shown`, `risk_notice_ack`, `alert_created`, `alert_opened`, `ai_question` (intent only), `ai_card_action`, `deep_link_opened` (path pattern, valid), `push_opened`, `connection_changed` (throttled 1/min), `error_shown` (code) | M | G each journey J-1…J-6 · T the listed events fire once per action with documented params |
| FR-188 | Privacy and isolation: no free text (AI question text never sent), no device ids beyond the provider's own, no ₹ amounts; a sink that throws is caught, logged once, and never affects the app | M | G sink throws on every call · W J-2 · T order placed, 1 log line, 0 crashes |
| FR-189 | Analytics on/off toggle in Settings; off → no sink receives events | S | G off · W J-2 · T fake sink 0 events |

**Totals:** 142 FRs — Must 111, Should 25, Could 6 (FR-28 Could deferred to v2.1) (counted in §12).

---

## 5. Non-functional requirements

### 5.1 Reference devices (**needs user confirmation at Gate 1**)

| Role | Proposed device | Used for |
|---|---|---|
| Primary perf reference (Android) | **Google Pixel 6a, Android 15**, 60 Hz mode forced (closest common mid-range; Rohan/Arjun class) | NFR-1…NFR-6, NFR-16 pass/fail |
| Secondary (iOS) | **iPhone 13, iOS 18 or later** | NFR-1…NFR-5 reported, not gating; haptics and VoiceOver manual pass |
| Local checks | **macOS desktop build** | Functional, widget and integration tests only; never used for perf numbers |

Emulators and simulators do not give valid frame numbers. If the user has no Pixel 6a, any 4–6 GB Android phone
named at Gate 1 replaces it.

### 5.2 Budgets and measurement

Measured in **profile** mode, local server on the same Wi-Fi, battery > 50 %, unplugged, data cleared except where a
warm cache is needed. Tools and run counts as in `team/reviews/prd-qa.md` §3. On 90/120 Hz screens the pass rule is
the **16.7 ms** budget; the native-budget figure is reported for information.

| ID | Area | Requirement | Budget | Runs / pass rule |
|---|---|---|---|---|
| NFR-1 | Startup | Cold start → first frame (`timeToFirstFrameMicros`) | p50 ≤ 800 ms, p90 ≤ 1.2 s | 10 cold runs (force-stop) |
| NFR-2 | Startup | Cold start → `cache_painted` | p50 ≤ 1.0 s | 10 warm-cache runs |
| NFR-3 | Startup | Cold start → `first_live_tick_painted` | p50 ≤ 2.0 s | 10 runs |
| NFR-4 | Rendering | 50-row watchlist (FR-7 data, real path), all rows ticking 4 Hz, scripted fling 20 s | build and raster p90 < 16 ms; missed frames ≤ 1 % | 5 runs, median |
| NFR-5 | Rendering | 41-strike chain ticking 4 Hz, scripted scroll + Back to ATM; rebuilds per tick ≤ changed cells | as NFR-4 | 5 runs, median |
| NFR-6 | Latency | `frame_received(seq)` → `price_painted(seq)` | p90 ≤ 50 ms | 3 × 60 s |
| NFR-7 | Correctness | §3.1 implemented exactly; tests at 4.9 / 5.0 / 5.1 s and +30 s skew | all pass | unit + widget |
| NFR-8 | Correctness | No POST possible on a stale traded instrument, including stale arising between tap and send | 0 POSTs | widget (fake clock) + integration (FR-121) |
| NFR-9 | Correctness | Lot size, tick, band from metadata only | fixture override test (lot 50) passes | — |
| NFR-10 | Reliability | Backoff + jitter, resubscribe, resync; no duplicate fills, banners or haptics | counts = 1 | integration |
| NFR-11 | Reliability | Server killed and re-served on the same port → Live and ticking ≤ 10 s after it accepts connections; positions equal server; subs restored once | 20/20 runs | integration loop |
| NFR-12 | Accessibility | 360×800, text scale 2.0, bundled font: no overflow (`takeException` null) on watchlist, chain, order sheet, portfolio; `textContrastGuideline` and `androidTapTargetGuideline` pass; up/down never colour-only; semantics labels per UX §8 | goldens + guidelines pass | widget; manual TalkBack/VoiceOver |
| NFR-13 | Ergonomics | Buy, Sell, Confirm, Exit in bottom 25 % at 360×800 and ≥ 48×48 dp | widget test | — |
| NFR-14 | Battery | Background: 0 subs within 2 s; chain subscribes visible strikes + buffer via one chain sub; off-screen cards unsubscribe ≤ 1 s | exact counts (FR-124) | integration |
| NFR-15 | Observability | Crash hook (`FlutterError.onError` + `PlatformDispatcher.onError`) to a pluggable reporter; FR-125 marks; docs table with device, OS, build SHA, date, medians | table filled | — |
| NFR-16 | Memory | Chain open: RSS ≤ 250 MB; heap at 10 min ≤ heap at 1 min + 10 MB | DevTools snapshots | 2 snapshots |
| NFR-17 | Testability | Every Must FR ≥ 1 automated test matching its acceptance; FR-120…126 in place before stories that depend on them | — | — |
| NFR-18 | Maintainability | Manual Riverpod 3 providers, hand-written immutable classes/JSON, no codegen, **including gen_l10n** (ADR-0018, v1.5); state + controllers in the **application layer** per HLD v2 (CR-1.1, CR-1.5) — amended v1.4 | architecture review | — |
| NFR-19 | Testability (v1.4, **M**) | **100 % line coverage** of Dart code under `lib/` of `stock_pulse`, `market_server` and `packages/option_math`, measured by `flutter test --coverage` / `dart test --coverage` + lcov, gated in CI. **Exclusion list (closed):** (1) the `main()` entry files (`lib/main.dart`, and any flavour `main_*.dart`), each ≤ 15 lines and only calling `bootstrap()`; (2) native Kotlin/Swift/Gradle/Xcode files (not Dart; covered by the manual platform pass and FR-101 tests). Nothing else: no `// coverage:ignore` pragmas (CI fails on any), locale string tables (`core/l10n/locales/**`) are not excluded: a test reads every string of every locale (v1.5) | CI: `lcov` summary 100.0 % lines, 0 ignore pragmas | every PR |
| NFR-20 | Process (v1.4, **M**) | **TDD**: each story's tests are written first and seen failing; the story's PR or task note records the red run (test name + failure) before the green run; reviewers reject code without a test that drove it | review checklist item ticked on every story | every story |
| NFR-21 | Reliability (v1.4, **M**) | Every row of the failure table §7a has ≥ 1 automated test (unit, widget or integration as noted), and each LLD carries its feature's failure table | qa-lead trace §7a → test names: 0 gaps | before Gate 3 |
| NFR-22 | Startup (v1.4, **M**) | NFR-1…NFR-3 budgets unchanged after icon, splash, l10n, router, push and analytics land. Nothing new is awaited before `runApp`; push and analytics init start after the first frame; l10n for `en` loads synchronously | NFR-1…3 budgets; trace shows push/analytics init after `first frame` | 10 cold runs |
| NFR-23 | Rendering (v1.4, **M**) | Chart with 4 studies (incl. RSI pane) + 10 drawings, 1D 1m, ticking 4 Hz, scripted pan + pinch 20 s; landscape rotation keeps state with 0 refetches | build and raster p90 < 16 ms; missed frames ≤ 1 % | 5 runs, median |
| NFR-24 | Engineering rules (v1.4, **M**) | ER-1…ER-10 (§5.3) pass: CI checks where automatable, review checklist otherwise | CI green + review checklist | every PR |

### 5.3 Engineering rules from CR-1 (owned by the architect; detail in HLD v2, ADRs, TRD)

| ID | CR | Rule (product intent; architect decides the how) |
|---|---|---|
| ER-1 | CR-1.1 | Providers declared at feature level, not inside the data layer |
| ER-2 | CR-1.5 | Clean architecture with an application layer (state + controller); presentation is pure UI |
| ER-3 | CR-1.8 | Core may be layered (core features with their own domain/data/application) |
| ER-4 | CR-1.3 | Human-written style: no redundant or narrating comments, no boilerplate that does nothing |
| ER-5 | CR-1.4 | No source file over 300 lines (CI check; generated files exempt only if the ADR allows them) |
| ER-6 | CR-1.6 | Import style per ADR (package imports preferred), enforced by lint |
| ER-7 | CR-1.7 | Clearer names for `Result` success/failure, per ADR |
| ER-8 | CR-1.9 | `core/providers.dart` justified or removed, per ADR |
| ER-9 | CR-1.10 | Further best practices adopted by the architect and reviewer are listed in the TRD |
| ER-10 | CR-1.15 | go_router is the router (replaces the earlier no-go_router decision), per ADR |

---

## 6. User journeys

**J-1 Cold start at 09:14 (Meera, M1)**
1. Taps the icon; first frame (NFR-1).
2. Cached watchlist and summary painted, grey, "as of 15:30 yday" (FR-80, FR-81).
3. Chip "Pre-open"; equities show IEP (§3.2); socket Live.
4. 09:15:00 ticks arrive; each row turns live on its own frame (FR-91).

**J-2 09:15 chain trade (Arjun, M2/M3) — release smoke test**
1. Options tab (tap 1, NIFTY is already the last viewed underlying): NIFTY chain, nearest weekly, ATM centred, "Expires today" (FR-22, FR-24, FR-29b).
2. Taps ATM CE (tap 2) → Buy; first F&O order → risk notice once (FR-113); sheet prefilled NRML, 1 lot, "65 qty · ₹X".
3. Sets 2 lots, Confirm (tap 3); exactly one POST (FR-31).
4. Fill: snack + haptic once (FR-100); position row with live P&L (FR-41).

**J-3 Alert in a cab (Meera, M5)**
1. Alert RELIANCE ≥ 1500 fires; banner (FR-51, FR-52).
2. Tap → stock page → Sell → limit sheet prefilled with LTP.
3. Network drops: banner "Prices not live", Confirm disabled with reason (FR-90, FR-38).
4. Network returns: Confirm enabled, inputs kept (FR-92); she confirms.

**J-4 First option buy with AI help (Rohan, M8/M9)**
1. AI tab; chip "What does the NIFTY chain say?" (FR-65).
2. Cards stream over NDJSON: live quote, chain snippet, text, all "Simulated. Not advice." (FR-60…63, FR-67).
3. "View payoff" → builder: max loss = premium × 65 (FR-72).
4. "Trade this strike" → prefilled sheet "From AI chat", not submitted; nudge "Expires today" (FR-64, FR-36).

**J-5 P&L between meetings (Meera, M6)**
1. Portfolio → Holdings: invested, current, Day, Total (FR-45, FR-47).
2. Positions: card switches to today's realised + unrealised; MIS row "Auto square-off 15:20" (FR-43).

**J-6 Expiry last hour (Arjun, M7)**
1. Debug clock 15:19:50 (FR-111); MIS and expiring badges.
2. Exit one position (FR-42); at 15:20:00 remaining MIS squared off with notice (FR-44).
3. At 15:30:00 NRML expiring option settles at intrinsic (FR-49); chain moves to next expiry (FR-29c).

---

## 7. Edge cases and error states

| # | Case | Expected behaviour |
|---|---|---|
| E1 | First install offline, no cache | Empty states "Connecting…" + retry; no fake zeros |
| E2 | Cache corrupt / old schema / > 7 days | FR-87 |
| E3 | Socket live, one instrument silent > 5 s | Only it is stale; its sheet blocked (FR-91, FR-38) |
| E4 | Sequence gap | FR-84 |
| E5 | Stale while sheet has inputs | Inputs kept, Confirm disabled, re-enabled on live (FR-38, FR-92) |
| E6 | Order sent, socket drops before fill | Pending → final state after resync; one notice, one haptic (FR-31a, FR-84, FR-100) |
| E7 | Server rejects (band, tick, funds, holdings, market closed) | Reason over the sheet, rejection haptic |
| E8 | Expiry rolls while chain open | FR-29c |
| E9 | ATM changes rapidly | Highlight moves, offset unchanged (FR-23) |
| E10 | Lot size missing | F&O sheet blocked "Contract data unavailable" |
| E11 | Funds insufficient | `insufficient_funds`; nudge shown earlier above 25 % |
| E12 | Alert crosses while backgrounded | Delivered on resume via resync, once (FR-54, FR-55) |
| E13 | Chat unknown intent / error mid-stream | Fallback with chips / FR-67 |
| E14 | Text scale 200 % on 360 dp chain | Chain keeps LTP · STRIKE · LTP (+ OI if it fits); no horizontal scroll (UX §8) |
| E15 | Haptics channel missing | FR-101 |
| E16 | Clock override or demo mode | "Demo clock" chip always visible |
| E17 | Retry after timeout, outcome unknown | FR-31a |
| E18 | App killed with order in flight | FR-31a; no auto-resubmit |
| E19 | Alert banner while sheet open | Queued, bell dot (FR-52) |
| E20 | Underlying stale, contract live | Nudge "Underlying price not live", Confirm enabled (§3.1) |

### 7a. Failure-case table (v1.4, CR-1.13; normative, NFR-21)

Every row needs at least one automated test (U unit, W widget, I integration using FR-121/FR-122 hooks). Snackbars
follow FR-156/FR-157 (one at a time, repeats dropped). No failure may crash the app, show a blank screen, show a fake
zero, or place, cancel or duplicate an order.

| # | Failure | Where | Expected behaviour | User sees | Test |
|---|---|---|---|---|---|
| F1 | Network down at cold start | startup | Cached content painted stale (FR-80, FR-81); socket retries with backoff; no cache → E1 empty states | Offline badge, grey prices "as of", "Connecting… · Retry" | W + I |
| F2 | Network drops mid-session | socket, REST | Socket Reconnecting → Offline; prices stale within 5.25 s; Confirm blocked; REST calls fail fast with a network error | Badge, global stale banner, Confirm reason | I (FR-121, drop) |
| F3 | REST timeout | all REST | Reads: one retry, then an inline error with Retry. Order POST: FR-31 / FR-31a (same key, ≤ 2 retries, Pending) | Inline "Couldn't load · Retry"; order "Placing… checking status" | U + I (FR-122 delayMs) |
| F4 | 4xx: 400/422 validation, 401 bad token, 404 unknown id, 409 duplicate key, 429 rate limit | REST | 400/422 → server reason over the sheet; 401 → persistent session banner "Demo session expired · Restart demo" under the app bar (a state, not a snackbar; Q-UX-3, v1.5), server actions disabled, cached content readable, no retry loop; 404 → item removed from the list on refresh; 409 → treated as the original order (idempotent); 429 → back off (respect `Retry-After`, default 2 s), no user retry storm | Specific reason text, never a raw code | U per code |
| F5 | 5xx | REST | Reads: one retry after 1 s, then inline error. POST: FR-31 retry with the same key | Inline error / Pending | U + I (FR-122 status 5xx) |
| F6 | Malformed data: bad JSON, missing or wrong-type field, unknown enum, unknown card type | REST, socket, cache | Parsing never throws past the data layer; bad REST body → error result; bad socket frame dropped, counted, logged once per type, resync if a seq is skipped; unknown AI card → text fallback (FR-60); bad cache → FR-87 | Inline error or nothing (frame drop) | U (fixtures per DTO) |
| F7 | Server restart (same port) | socket, REST | Reconnect, resubscribe, full resync; Live ≤ 10 s (NFR-11); seq reset detected (new session id) and the snapshot accepted | Reconnecting → Live | I (NFR-11 loop) |
| F8 | Device clock skew / time change | stale rule, charts | All freshness uses server-adjusted time (§3.1); a device time change while running re-syncs on the next pong; candle buckets use server time | Nothing different | U (+30 s, −30 s, jump) |
| F9 | Empty data: no candles, empty watchlist, no chain for a symbol, no positions/holdings/orders/alerts, study period > candles | screens, chart | Designed empty states per UX spec; study shows "Not enough data for SMA(200)" chip, no line; never a fake zero or spinner forever | Empty-state text + action | W per screen |
| F10 | Permissions denied (notifications; no other permission is used) | push | In-app alerts unaffected; Settings shows "Notifications off"; asked again only from Settings | Status text | W (fake `PushService`) |
| F11 | Low storage / write fails (cache, drawings, prefs, seen-set) | storage | Write failure caught; app keeps working from memory; one log; cache retried at the next save; seen-set failure never shows a duplicate banner in the same run | Nothing, or one snackbar if drawings fail to save "Couldn't save drawing" | U (fake storage throws) |
| F12 | App killed mid-order | orders | FR-31a: relaunch reads `GET /orders`; never auto-resubmit; one outcome notice and haptic | Pending → final status | I (kill during POST) |
| F13 | Backgrounded / killed during socket or chat stream | lifecycle | FR-85 close ≤ 2 s; chat request cancelled, received cards kept; resume resyncs | Resumes live | W (fake lifecycle) |
| F14 | Bad deep link or push payload | router | FR-177 nearest valid screen + one snackbar; unknown push type ignored and logged | "Link not available" | U + W |
| F15 | Push init / token failure | push | No-op fallback; app unaffected; logged once | Nothing | U |
| F16 | Analytics sink throws or is slow | analytics | FR-188: caught, logged once; logging never blocks the UI isolate's frame | Nothing | U |
| F17 | Repeated bad taps (disabled Confirm, rejected order) | feedback | FR-156: disabled Confirm → inline reason + haptic, 0 snackbars; repeated rejections → 1 snackbar, repeats dropped (v1.5) | Reason line, or one snackbar | W |
| F18 | Missing translation key or asset | l10n, assets | English fallback (FR-164); missing asset shows the registry's placeholder icon; a test fails in CI before release | English text / placeholder icon | U (every key and asset path resolves) |

---

## 8. Success metrics and milestones

| Metric | Target |
|---|---|
| Must FRs implemented with tests | 100 % |
| NFR-1…NFR-6 measured on the confirmed reference device, in docs | all six with numbers |
| POSTs possible on a stale traded instrument | 0 |
| Taps Options tab → confirmed order | ≤ 3 |
| Alert → order sheet | ≤ 2 taps |
| Duplicate fills / banners / haptics after resync | 0 |
| `flutter analyze` warnings / failing tests | 0 / 0 |
| Open blocking review findings | 0 |
| Line coverage of `lib/` (NFR-19) | 100.0 % |
| §7a failure rows without a test (NFR-21) | 0 |

| Milestone | Contents |
|---|---|
| **M-A Foundation** | Test hooks FR-120…126; market clock §3.2 + FR-111, FR-116; stale rule FR-90…95; instruments FR-6, FR-7; cache-first FR-80…82, FR-86, FR-87; haptics FR-100, 101; resync FR-84 |
| **M-B F&O core** | Chain FR-20…26, 29a–c; orders FR-31a, 32…34, 37, 38, 38a, 39a; positions FR-41…43, FR-49; risk notice FR-113 |
| **M-C Portfolio + alerts** | FR-45, 47, 48; alerts FR-50…52, 54, 55 |
| **M-D AI + payoff** | FR-60…65, 67; FR-70…72 |
| **M-E CR-1 (v1.4)** | Foundation first: FR-155…157, FR-160…163, FR-175…180, FR-185…188, NFR-19…22, ER-1…ER-10 (refactor of wave 0–1 code); then charts FR-130…134, 138…141, 143…145; icon/splash FR-170, 171 |
| **v2 MVP release** | All Must FRs; NFRs measured/passed; QA, design, engineering, product sign-offs |
| **v2.1** | Should/Could not finished: SL, nudges, funds UI, greeks, T+1, MIS auto square-off, alert list mgmt, crosshair, overlay, BANKNIFTY; **FR-28 PCR / max pain (deferred, C16)**; CR-1 Should/Could: Bollinger, MACD, Fibonacci, log scale, chart memory, alert/limit at price, Supertrend, hollow candles, compare, prev/next, pseudo-locale, dark splash, push permission flow, analytics toggle; chart Later list (§4.8a) |

---

## 9. Out of scope

| Item | Note |
|---|---|
| Real broker / exchange, real money, margin (SPAN/exposure) | Short options allowed, "Margin not simulated" |
| Login, signup, KYC, multiple users | Demo token only |
| Real LLM / API keys; personalised advice | Rule-based server chat |
| SL-M, GTT, cover/bracket, AMO, baskets, multi-leg atomic orders | Backlog |
| BANKNIFTY, SENSEX, futures, commodities, currency | Backlog (D-1) |
| Real OS push delivery, push server, background alerts | Foreground socket only; push is an interface with placeholders (FR-179…181) |
| Swipe-to-trade, swipe-to-delete | Dropped for one-handed safety (UX Q1) |
| Tablets, landscape (except the full-screen chart, FR-144), web target | Phone portrait first; macOS for local checks only |
| Tax, contract notes, ledger, add/withdraw funds | Not simulated |
| Translations beyond English (Hindi etc.) | Structure is ready (FR-160…164); adding a language = one set of string tables per ADR-0018. INR formatting stays lakh/crore |
| Chart Later list (Renko/Kagi/P&F, extra intervals, full indicator library, layouts, order lines, depth in chart, GTT) and instant order placement | §4.8a; instant orders rejected (D-4) |

---

## 10. Review answers (v1.1)

| Reviewer | Item / question | Decision | Changed |
|---|---|---|---|
| QA | H1 stale rule clock and boundary | Server-adjusted time; stale when age > 5.0 s; 5.0 s is live | §3.1, FR-94, NFR-7 |
| QA | H2 per-instrument vs socket stale | Split into two cases; per-symbol freeze hook | FR-5, FR-91, FR-121 |
| QA | H3 stale after Confirm | No POST if stale at send time; in-flight POST not cancelled, final status shown | FR-38, FR-38a, NFR-8 |
| QA | H4 retry, reconnect, kill during submit | Same key, ≤ 2 retries, "checking status" state, Pending until resync, never auto-resubmit | FR-31, FR-31a, FR-122 |
| QA | H5 phase edges | [start, end) boundaries; 09:15:00.000 inclusive; square-off ≥ 15:20:00.000 | §3.2, FR-37, FR-44 |
| QA | H6 sequence rule | Never apply a value older than the snapshot seq; resync reloads orders/positions/alerts | FR-84 |
| QA | H7 alert dedupe | `alertId` + `triggeredAt`; persisted seen-set; 1 banner per id | FR-51, FR-55 |
| QA | M/L rewrites (build counts, scroll offset, lot fixture, band numbers, card timing, sub counts, cache, lazy tabs, background, fake channel, 48 dp, restart, goldens, memory) | All accepted as written in the QA review | FR-1, 23, 33, 34, 60, 63, 82, 85, 87, 100, 12; NFR-11, 12, 13, 16 |
| QA | Q1 reference device | Pixel 6a / Android 15 (60 Hz) primary, iPhone 13 secondary, macOS local only — **user to confirm** | §5.1 |
| QA | Q2 clock source | Server-adjusted | §3.1 |
| QA | Q3 09:15 / 15:20 inclusive | Yes, both inclusive | §3.2 |
| QA | Q4 user view during retry | "Placing… checking status", then Pending + snack | FR-31a |
| QA | Q5 stale underlying vs live contract | Block only on the traded contract; underlying stale = nudge | §3.1, D-7, E20 |
| QA | Q6 max cache age | 7 days | FR-87 |
| QA | Q7 90/120 Hz | Pass rule on 16.7 ms; native budget reported; primary device forced to 60 Hz | §5.2 |
| QA | Q8 holiday list | Yes, config table with source date; tests inject | §3.2, FR-24 |
| QA | Test hooks | Accepted as Must | FR-120…FR-126 |
| Architect | H1 50-sub cap vs chain; 31 vs 40 strikes | `chain` channel; **41 strikes (±20)** everywhere | FR-20, FR-29a, NFR-5 |
| Architect | H2 `asOf` meaning, skew | Last server confirmation + 2 s keep-alive; offset from `serverTime` | §3.1, FR-93…95 |
| Architect | H3 virtual clock | `MarketClock` with offset + `jumpTo`, injected everywhere | §3.2, FR-120, FR-123 |
| Architect | H4 expiry settlement | Cash-settle at intrinsic 15:30 expiry day; next far expiry listed at day roll | FR-49, §3.2 |
| Architect | H5 IndexedStack builds all tabs | Lazy tabs + visibility unsubscribe | FR-82, FR-86 |
| Architect | Q2 50-row watchlist source | Server adds simulated NIFTY 50 names (50 equities + index); quote cap 100. Perf test uses the real data path | FR-7, NFR-4 |
| Architect | Q4 option band | Accepted: ₹0.05 to 3× prev close; equities ±20 %; from metadata | FR-34 |
| Architect | Q5 funds | Accepted: debit/credit on fill, nothing blocked, short options allowed and labelled; plus insufficient-funds and CNC-holdings checks | FR-39, FR-39a |
| Architect | Q6 AI transport | **HTTP NDJSON**: chat is request/response, must not consume the market `seq` (a lost card would force a quote resync), cancels by closing the request, easy to test; live prices still on the socket | FR-67, FR-63 |
| Architect | Q7 clock default | `demo` (Open from 10:00 virtual) by default, `real` by flag | FR-116 |
| Architect | Q8 pre-open | Equity IEP drifts; options frozen at prev close; equity limits queued and matched at 09:15 | §3.2, FR-37 |
| Architect | Q9 NIFTY rows | Chart, Option chain, Set alert only; no Buy/Sell/depth | FR-4, FR-6 |
| Architect | Medium/Low items (positions key, fixed strike set, alert/order resync, `option_math`, JSON snapshot, banner by frame age, haptic key, router, caps, reset) | All accepted; router choice is the architect's (no codegen) | FR-41, 20, 84, 27, 80, 90, 100, 110, 66, 112 |
| UX | Q1 drop swipe | Accepted: long-press + `⋮` | FR-4, §9 |
| UX | Q2 where to block | Accepted: buttons enabled, block at Confirm | FR-12, FR-38 |
| UX | Q3 Options tab default | Updated: last viewed; no implicit first-run underlying, show chooser | FR-29b |
| UX | Q4 summary card | Accepted: context card per tab | FR-47 |
| UX | Q5 "Not now" on notice | Accepted | D-7, FR-113 |
| UX | Q6 extra grace | Accepted: no extra grace; keep-alive hides sub-5 s blips | §3.1 |
| UX | Q7 stale AI card button | Accepted: rely on the sheet | FR-64 |
| UX | Q8 banner during sheet | Accepted: queue + bell dot | FR-52 |
| UX | R6 Refresh status on a Pending order while offline | Disabled with "Waiting for connection" only when Offline (no network); enabled while the socket is Reconnecting because REST can still answer; resync updates Pending rows automatically. Adjusts UX R6 (which disabled it whenever the socket was down) | FR-31a |
| UI design | Buy blue / Sell red, green/red only for up/down | Accepted | FR-2, FR-12 |
| UI design | Nav "Watchlist, Chain, Orders, Portfolio, Assistant" (§7) vs UX "Watchlist, Options, AI, Portfolio, More" | **UX version wins**: Orders is a Portfolio sub-tab; More holds alerts, builder, settings, debug. UI designer to update §7 | FR-48, FR-110 |
| UI design | "Required margin" row in OrderTicket | **Rejected**: margin is not simulated; replace with "Funds available" and "Margin not simulated" on short sells | FR-39 |

---

### 10.1 Product sign-off coverage check (v1.1)

Every Must FR with a user-visible surface maps to a screen or shared pattern in `03-ux-spec.md` (watchlist, stock page, chain, order sheet, portfolio, alerts, AI chat, strategy builder, settings/debug, risk notice, stale pattern §4). Must FRs with no screen by nature (server, protocol or test hooks: FR-7 server data, FR-29a, FR-84, FR-85, FR-87, FR-93, FR-95, FR-101, FR-120…FR-126) are covered by the TRD and test plan. **No gaps found.**

## 11. For the user at Gate 1

1. **Reference devices:** OK to measure on a Pixel 6a (Android 15) with an iPhone 13 as secondary, using macOS for local checks only? If you own other phones, name them.
2. **Scope:** confirm D-1 (NIFTY + RELIANCE + HDFCBANK, no BANKNIFTY) and D-4 (stale blocks orders, no override).
3. **Milestone cut:** OK that Should items (SL orders, nudges, greeks, T+1 roll, MIS auto square-off) can slip to v2.1 if M-D runs late?

---

## 11a. For the user at Gate 2

1. FR-28 (PCR / max pain on the chain header, Could) was deferred to v2.1 to keep the chain work smaller; PCR is still shown in the AI chain card. Object if you want it in v2.

## 11b. For the user at the wave 1 check-in (CR-1)

1. **Chart Musts:** the v2 Must set is SMA, EMA, VWAP, RSI, OHLC readout, horizontal + trend line, saved drawings, landscape full-screen and Buy/Sell from chart; Bollinger, MACD, Fibonacci and Supertrend are Should/Could. Do you want any of those (or Renko / multi-chart layouts) promoted to Must, knowing it adds chart work before release?
2. **Coverage scope:** NFR-19 applies 100 % line coverage to `stock_pulse`, `market_server` and `option_math` with only `main()` and native code excluded. OK to include the server and package, or app `lib/` only?
3. **Deep-link host and languages:** `stockpulse.example` is a placeholder https host. Do you have a real domain to put in the App Links / Universal Links templates, and is Hindi the first language to plan for?

## 12. Counts

| Kind | Must | Should | Could | Total |
|---|---|---|---|---|
| FR | 111 | 25 | 6 | 142 |
| — of which new in v1.4 | 31 | 11 | 4 | 46 |
| NFR | — | — | — | 24 (NFR-19…24 new in v1.4, all Must) |
| Engineering rules (§5.3) | — | — | — | 10 |
