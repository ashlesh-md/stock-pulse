# PRD review: architect

Reviewer: architect · Input: `docs/02-prd.md` (draft for scope gate), v1 code at `market_server/lib/src/*`, `stock_pulse/lib/core/*`, `stock_pulse/lib/app.dart`

## 1. Verdict

**Feasible with changes.** Nothing in the PRD needs a new technology; the v1 socket client and server already solve the hardest
generic problems (ref-counted subscriptions, resync, backoff, idempotent orders). But five items are not buildable as written:
the 50-symbol subscription cap vs the chain (FR-20, NFR-5), the meaning of `asOf` and clock skew (FR-90…93), the market clock
needing virtual time (D-5, FR-44, FR-46, FR-111), the missing expiry settlement rule (FR-24, FR-41, E8), and tab/route
visibility vs the frame and battery budgets (FR-82, NFR-4, NFR-14). Each has a cheap fix below.

## 2. Findings by requirement

| ID | Concern | Suggested change | Sev |
|---|---|---|---|
| FR-20, NFR-5 | `_Session.maxSubscriptions = 50` (`ws_gateway.dart`). 40 strikes × CE/PE = 80 contracts, plus watchlist and chat cards. Also FR-20 says ±15 (31 strikes), NFR-5 says 40 | New `chain` channel: one subscription = underlying + expiry + strike range; does not count against the 50. Fix one strike count (suggest 41 = ±20, visible ±15) | High |
| FR-93, FR-91, D-4 | v1 `quoteJson` sends `t` = `lastTradeTime`. If `asOf` = last trade, a quiet OTM strike goes stale and blocks its own order sheet. Device clock vs server clock not defined | Define `asOf` = server time the value was last confirmed (stamped at flush, refreshed by a per-session keep-alive at ≤ 2 s for unchanged subs). Client compares to **server-now** = device-now + offset from `welcome`/`pong` `serverTime` | High |
| D-5, FR-44, FR-46, FR-111 | "Force a phase" alone cannot reach 15:20 square-off or next-day roll. `MarketEngine` already takes `clock`, but its timer and the gateway use `DateTime.now()` | One server `MarketClock` (wall time + offset, `jumpTo(t)`), injected into engine, broker, alerts, expiry calendar, gateway. Debug endpoint sets offset. Engine stops trading when Closed | High |
| FR-24, FR-41, E8 | No rule for open NRML option positions at expiry; no rule for listing the next expiry | Add FR: at 15:30 on expiry day, cash-settle at intrinsic value, move to realised P&L, send `order`-style `settlement` frame; new far expiry is listed at day roll | High |
| FR-82, NFR-4, NFR-14 | `app.dart` uses `IndexedStack`: all tabs built and subscribed at startup. Routes under the chain (watchlist) keep their streams and rebuild at 4 Hz | Lazy tabs (build on first visit) + a visibility signal (`TickerMode`/route-aware) that cancels repository streams for hidden screens; subscription-count test | High |
| NFR-4 | 50-row watchlist but server has 12 instruments (`instruments.dart`) + NIFTY | Either add ~40 simulated NSE stocks, or define the perf test on a 50-row synthetic list. With the 50 cap, the watchlist alone fills a session | Medium |
| FR-3, FR-4, FR-11, FR-12 | NIFTY is an index: no depth, no volume, not tradable. `Instrument` has no kind | Add `kind: index/equity/option` to instrument metadata; hide Buy/Sell/depth for indices | Medium |
| FR-34 | `Broker.place` rejects limits > 20% from prev close. Options routinely move 50–100% a day, so valid option limits get rejected | Band per instrument in metadata (`bandLow`, `bandHigh`); options use a wide operating range (e.g. 0.05 to 3× prev close). PM to confirm | Medium |
| FR-32, FR-41, FR-45 | `Broker._positions` keyed by symbol only. MIS and CNC of the same stock, or MIS vs NRML, must not net | Key positions by (symbol, product); holdings a separate book; CNC sell > held qty rejected | Medium |
| FR-39 | Funds semantics undefined: do open limit orders block funds? Does selling an option credit premium? Short options with no margin = unlimited | Rule: buy debits on fill, sell credits on fill, no blocking; short options allowed and labelled "margin not simulated" | Medium |
| FR-23, E9 | If the strike window re-centres on spot, rows are inserted/removed and the list jumps | Fixed strike set per expiry per day; ATM is a highlight, not a re-index. Rows keyed by strike, fixed `itemExtent` | Medium |
| FR-51, FR-54, NFR-10 | "No duplicate alerts" + "missed alerts on resync" need a delivery rule. v1 resync (`market_repository.dart _resync`) reloads quotes only; orders and alerts are not reloaded after a gap | Alerts have id + `triggeredAt`; resync = REST `GET /alerts` and `GET /orders`; client keeps a persisted seen-set so banner and haptic fire once | Medium |
| FR-60, FR-63 | Streaming protocol not chosen; chat card prices also need `asOf` | See §3.3. Versioned card schema, unknown type → text fallback | Medium |
| FR-71, FR-27 | "Today line" needs Black-Scholes on the client too; greeks on the server. Two copies of the maths drift | Pure-Dart `packages/option_math` (path dependency, no codegen) used by server and app | Medium |
| FR-80, NFR-2 | Storage choice not stated; pubspec has no storage package | §3.4: JSON snapshot file + `shared_preferences` for flags | Medium |
| FR-90 | v1 `SocketConfig.staleAfter` is 12 s, so on a freeze the badge says Live for 12 s while prices are 5 s old | Banner driven by "last frame age > 5 s" as well as status; keep 12 s for reconnect | Low |
| FR-100, E6 | Resync can replay a fill; FR-100 requires the channel called once | Haptic keyed on (orderId, status) transition, not on every `order` frame | Low |
| FR-52, FR-64 | Banner tap and AI actions navigate from anywhere; v1 has no router | Add `go_router` (no codegen) or a root navigator key; deep-link style routes with prefill args | Low |
| NFR-16 | 250 MB is fine for the chain itself; risks are Socket Lab frame log, chat history, 2000-candle lists | Cap Socket Lab buffer and chat history; measure | Low |
| FR-112 | Reset must also clear local state (risk-notice ack, alert seen-set, cache) | Reset = server call + local wipe in one use case | Low |

## 3. Key technical risks

### 3.1 Option chain volume and rebuild cost
- Server load is trivial: D-1 gives ~3 underlyings × 2 expiries × 41 strikes × 2 ≈ 500 contracts. Price options **from** a
  smile IV with closed-form Black-Scholes (no IV solving); ~500 evaluations per 200 ms step is well under 1 ms.
- Because premiums follow spot, **nearly every cell changes every flush**. "Only changed cells rebuild" (NFR-5) will be true but
  near all visible cells. Visible rows on 360×800 ≈ 14 × 6 cells ≈ 84 `Text` rebuilds at 4 Hz: affordable if the list itself
  never rebuilds (rows `select` their strike from a `Map<strike, ChainRow>`, fixed `itemExtent`, `RepaintBoundary` per row).
- Wire: 82 compact entries per 250 ms ≈ 8–12 KB/frame, ~40 KB/s. JSON decode stays on the UI isolate (< 2 ms); move to
  `Isolate.run` only if the trace shows it. Use short keys and send only changed fields per strike.
- Risk to NFR-6 (50 ms p90): low; the main cost is frame scheduling, not decode.

### 3.2 Greeks and IV on the server
IV = smile function of moneyness and time to expiry, drifting slowly; premium = BS(spot, strike, T, r, IV); greeks closed form.
Time to expiry must use the **virtual clock** (§2 D-5 row) or theta looks wrong after a clock jump. OI: seeded per strike,
drifting with trades. Greeks only on the strike detail sheet (FR-27) and opt-in columns, so default frames carry LTP, OI, ΔOI only.

### 3.3 AI chat streaming
Options: (a) reuse the WebSocket with `ai.ask` / `ai.card` / `ai.done` frames; (b) `POST /api/v1/ai/ask` returning NDJSON
(one card per line) over HTTP. **I lean to (b):** a chat answer is request/response, it should not consume the market `seq`
(a lost card would trigger a quote resync), it cancels by closing the request, and it is easy to test. Cards that tick (FR-63)
do **not** carry live data in the stream: they carry instrument ids and subscribe through the normal ref-counted quote path while
visible. If the PM prefers one connection for the demo story, (a) works with its own per-request card index and no global `seq`.

### 3.4 Cache-first startup without codegen
Hive/Isar/drift all lean on codegen. Use **one JSON snapshot file** (`path_provider` + `dart:io`), `schemaVersion` + `savedAt`,
hand-written `toJson`/`fromJson` that already exist for `Quote`/`Position`. Write on pause and debounced every 30 s; read
**started in `main()` but not awaited before `runApp`** (first frame shows the shell, cached lists paint when the future
resolves). Corrupt or old schema → delete and log (E2). Small flags (risk notice, haptics, seen alerts) in `shared_preferences`.
Budget check: NFR-1 800 ms p50 on a 4 GB Android in profile is tight (engine init alone is often 400–600 ms); NFR-2 leaves
~200 ms for file read + decode + paint, which a < 100 KB file meets.

### 3.5 Market clock simulation
Biggest hidden cost. Today the engine trades 24/7 and buckets candles by IST day. Jumping the clock creates candle gaps and a new
`prevClose`, which changes day P&L (FR-45) and the price band. Expiry calendar (Tuesday weekly, last-Tuesday monthly, holiday
shift) must be pure and unit-tested against the clock. Demos at 20:00 IST would be Closed, so the dev default should be
offset-to-Open with the "Debug clock" chip (E16).

### 3.6 Platform channel scope
Small. One `MethodChannel('stockpulse/haptics')` with `success` / `rejection`; Android `View.performHapticFeedback`
(no VIBRATE permission) or `VibrationEffect` on API 29+; iOS `UIImpactFeedbackGenerator`/`UINotificationFeedbackGenerator`;
`MissingPluginException` → no-op (FR-101, E15). Note Flutter's own `HapticFeedback` exists; the custom channel is there for J9,
so the docs should say why. Keep it to this one channel.

## 4. Reuse from v1, and protocol changes

**Reuse as is:** `MarketSocket` (ref-counted subs, resubscribe, heartbeat, backoff + jitter, generation guard, seq gap → resync,
pause/resume); `ApiClient` + `Result`/`Failure`; idempotency key + one retry in `PortfolioRepository.placeOrder`; conflation and
modes in `ws_gateway.dart`; `MarketRepository._merge` older-snapshot guard (switch it from `t` to `asOf`); chaos endpoints
(drop / freeze / skip-seq) for NFR-8 tests; in-process `market_server` dev dependency for integration tests; candle charts.

**Must change:**

| Change | Where |
|---|---|
| `welcome` and every data frame carry `serverTime`; every quote/chain cell/card price carries `asOf` | `ws_gateway.dart`, `market_engine.dart` |
| `channel` field on subscribe: `quotes` (today), `chain` {underlying, expiry, fromStrike, toStrike, fields}, `orders`, `alerts` | `_Session._onMessage` |
| New server frames: `chain` (per-strike deltas), `order` (exists, now with product/lots), `position`, `alert`, `settlement`, `clock` (phase changes) | gateway + client `_onFrame` switch (today it forwards only `ticks`/`order`) |
| Orders and alerts to their own session (today `sendOrder` goes to every session) | `WsGateway` |
| Resync reloads orders, positions, alerts too, not just quotes | `MarketRepository._resync`, `PortfolioRepository` |
| REST: `/instruments` gains kind, lotSize, tickSize, band, expiry, strike; new `/chain`, `/holdings`, `/funds`, `/alerts`, `/clock`, `/debug/clock`, `/debug/reset` | `rest_api.dart` |
| Order body: `product`, `lots` (server multiplies by lot size), `triggerPrice` | `rest_api.dart`, `Broker.place` |

## 5. Questions for the PM

1. Strike count: 31 (FR-20) or 40 (NFR-5)? I suggest fetching ±20, showing ±15 by default.
2. 50-row watchlist (NFR-4): add ~40 simulated stocks to the server, or measure on a synthetic 50-row list?
3. Expiry settlement: OK to cash-settle open option positions at intrinsic at 15:30 on expiry day?
4. Option price band (FR-34): accept a wide per-instrument range from metadata instead of the 20% equity band?
5. Funds (FR-39): sells credit premium on fill and nothing is blocked for open orders; short options allowed with "margin not simulated"?
6. AI streaming: OK with HTTP NDJSON for chat answers (live prices still on the socket), or must it be the WebSocket?
7. Default clock in dev builds: real IST wall time, or offset so the market is Open whenever the demo runs?
8. Pre-open (FR-37): does the engine show an indicative price that moves, or freeze at prev close until 09:15?
9. Can NIFTY rows show Chart and Option chain only (no Buy/Sell, no depth)?

## Round 2 (PRD v1.1)

| Item | Status | Note |
|---|---|---|
| H1 50-sub cap vs chain; 31 vs 40 strikes | Closed | `chain` channel (FR-29a) outside the quote cap; 41 strikes (±20) everywhere; fixed strike set per day (FR-20); quote cap raised to 100 (FR-7) |
| H2 `asOf` meaning and clock skew | Closed | §3.1: last server confirmation, 2 s keep-alive, `serverNow` from `welcome`/`pong` offset; 250 ms re-evaluation timer |
| H3 virtual market clock | Closed | §3.2 `MarketClock` with offset + `jumpTo`, injected everywhere; `[start, end)` phase edges; client `Clock` (FR-120) |
| H4 expiry settlement | Closed | FR-49 cash-settle at intrinsic 15:30, `settlement` frame; next far expiry at day roll; FR-29c for open chain |
| H5 IndexedStack / covered routes | Closed | FR-82 lazy tabs, FR-86 visibility-based unsubscribe with test on released subs |
| Q1 strike count | Closed | 41 (±20) |
| Q2 50-row watchlist | Closed | 50 simulated equities + NIFTY (FR-7); perf test on the real data path |
| Q3 expiry settlement | Closed | FR-49 |
| Q4 option band | Closed | ₹0.05 to 3× prev close; equities ±20% (FR-34) |
| Q5 funds | Closed | FR-39, FR-39a (insufficient funds, CNC holdings) |
| Q6 AI transport | Closed | HTTP NDJSON (FR-67); live card prices on the socket (FR-63) |
| Q7 dev clock default | Closed | `demo` mode, Open from 10:00 virtual (FR-116) |
| Q8 pre-open | Closed | Equity IEP drifts, options frozen, equity limits queued to 09:15 (§3.2) |
| Q9 NIFTY rows | Closed | Chart / Option chain / Set alert only, no depth (FR-4, FR-6) |
| Medium/Low items | Closed | All accepted; router choice left to the architect (will pick in TRD, no codegen) |

**Residual notes (not blockers, carried into TRD/HLD):**
- NFR-1 (800 ms first frame p50) stays a measurement risk on the reference device; TRD will list the startup rules (nothing awaited before `runApp`).
- FR-44 MIS square-off is Should while FR-49 settlement is Must; both run off the same clock scheduler, so the server work is shared.
- The 2 s keep-alive for up to 100 quotes + a chain is a small constant load; HLD will size the frame.

**Result: all 5 High items and 9 questions closed. PRD v1.1 is ready for TRD/HLD/LLD.**
