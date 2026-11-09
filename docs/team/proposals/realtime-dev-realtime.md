# Proposal: real-time server and protocol (dev-realtime)

Input: PRD v1.1 §3.1, §3.2, change log C1–C4, C7–C9; architect review (High H1–H4, Round 2); v1 code `market_server/lib/src/*`, `market_socket.dart`, `market_repository.dart`.

## 1. Scope
FR-7, FR-14 (data), FR-20, FR-24, FR-29a, FR-29c, FR-34 (server band), FR-37 (server phase rules), FR-44, FR-46, FR-49, FR-50, FR-51, FR-54, FR-84, FR-85, FR-90…FR-95, FR-111 (server), FR-116, FR-120 (server + client `Clock`), FR-121…FR-124, FR-125 (`frame_received` mark only). NFR-5/6/10/11/14 (wire side). Shared package `packages/option_math` (FR-27, FR-71 consumers).

## 2. Design

### 2.1 Server modules (`market_server/lib/src/`)
| File | New/changed | Role |
|---|---|---|
| `market_clock.dart` | new | `MarketClock`: `now()` = wall UTC + `offset`; `jumpTo(t)`; `wallNow()`; mode demo/real. Only source of time for every module |
| `market_calendar.dart` | new, pure | `phaseAt(t)` with `[start,end)` edges, `isTradingDay`, `expiries(underlying, day)`, holiday table (`holidays` + `sourceDate`, injectable) |
| `clock_scheduler.dart` | new | Fires `dayRoll` 09:00, `open` 09:15, `squareOff` 15:20, `settle` 15:30, `close` 15:30 in order. On `jumpTo` forward it replays every boundary crossed (capped 10 trading days); backward jumps only via `/debug/reset` |
| `instruments.dart` | changed | 50 NIFTY-50 equities + NIFTY index; `kind`, `lotSize`, `tickSize`, `bandLow/High`, `strikeStep` |
| `option_instruments.dart` | new | Builds the fixed 41-strike set per (underlying, expiry) at day roll from `prevClose` (ATM ±20). Id `NIFTY-261110-24500-CE`. Lots: NIFTY 65, RELIANCE 500, HDFCBANK 550 (metadata only) |
| `option_pricer.dart` | new | Prices all contracts of an underlying when it ticks; uses `option_math` |
| `chain_book.dart` | new | Per chain: rows, per-session last-sent cells for field diffs, status open/expired |
| `market_engine.dart` | changed | Reads `MarketClock`; no ticks when Closed; Pre-open = equity IEP drift, options frozen; `quoteJson` adds nothing per quote (asOf is per frame) |
| `broker.dart` | changed | Positions keyed (symbol, product), holdings book, funds, SL, phase rules, `version` on every order |
| `alerts_engine.dart` | new | One-shot above/below alerts; crossing test `prev < level <= ltp` (or mirror); `alertId`, `triggeredAt`, `triggerLtp` |
| `expiry_service.dart` | new | Settlement at 15:30 (2.6), new far expiry at day roll, chain `expired` status |
| `ws_gateway.dart` | changed | Channels, keep-alive, `resync` op, quote cap 100, per-session routing of account frames |
| `debug_api.dart` | new | Moves `/debug/*`; adds `clock`, `freeze?symbol`, `faults`, `subscriptions`, `reset`; `faultInjection()` shelf middleware |

### 2.2 Market clock
Two times, never mixed: **wall time** (`serverTime`, `asOf`, staleness, keep-alive) and **market time** (virtual: phase, candles, expiry, T in pricing, order timestamps). `jumpTo` changes market time only, so a debug jump never makes prices stale. `clock` frame carries `marketOffsetMs` so the client shows "as of" in market time. Demo mode: offset set at start so market time is 10:00:00 IST on today or the next trading day. Engine and gateway timers stay real `Timer.periodic`; they read the clock each step. Tests: `FakeMarketClock` + `engine.step()` + `scheduler.advance()`, no real waiting.

### 2.3 Option pricing
Black-Scholes (European, r = 6.5%, q = 0) from a parametric smile, no IV solving. `iv(K,T) = atm(T) · (1 + skew·m + curv·m²)`, `m = ln(K/F)/√T`. Per-underlying ATM IV (NIFTY 13%, RELIANCE 22%, HDFCBANK 20%) is an Ornstein–Uhlenbeck walk (slow, mean-reverting); term structure via `atm(T) = atm·(1 + 0.15·e^(−T/0.05))`; NIFTY skew −0.12, stocks −0.08, curv 0.04. T in years from market time to 15:30 expiry, floored at 1 minute; at settlement the price is intrinsic. Premium rounded to tick, floor ₹0.05. OI seeded per strike (peak near ATM, puts below/calls above), drifts with simulated volume; ΔOI vs day-roll OI. Greeks and IV computed only when a session asked for those fields, at most 1 Hz. Cost: ~500 BS evaluations per 200 ms step, well under 1 ms.

### 2.4 Protocol frames (JSON text, short keys, `seq` per session on every data frame)
- Welcome: `{"type":"welcome","sessionId":"S4","serverTime":1762412400000,"flushMs":250,"keepAliveMs":1000,"clock":{...clock frame body}}`
- Chain subscribe (re-sending replaces the range; one sub per `chainId` per session, max 2):
  `{"op":"subscribe","id":7,"channel":"chain","underlying":"NIFTY","expiry":"2026-11-10","fromStrike":24100,"toStrike":25100,"fields":["l","oi","d"],"throttleMs":250}`
  Ack: `{"type":"ack","id":7,"op":"subscribe","channel":"chain","chainId":"NIFTY:2026-11-10","strikes":[23600,24600,50],"lot":65}`
- Snapshot (on subscribe, on range growth for new rows only, on resync):
  `{"type":"chain","seq":101,"kind":"snapshot","chainId":"NIFTY:2026-11-10","asOf":1762412400250,"spot":24612.35,"atm":24600,"status":"open","rows":[{"k":24600,"c":{"l":112.4,"oi":4521300,"d":12300},"p":{"l":98.1,"oi":3980100,"d":-4100}}]}`
- Delta (only changed fields): `{"type":"chain","seq":102,"kind":"delta","chainId":"NIFTY:2026-11-10","asOf":1762412400500,"spot":24613.1,"rows":[{"k":24600,"c":{"l":112.45}}]}`. `atm` only when it moves.
- **asOf rule:** a chain or ticks frame confirms **every** subscribed value of that chain/batch at `asOf`, changed or not. Values not confirmed (per-symbol freeze) are listed `"ex":{"NIFTY-261110-24600-CE":1762412395000}` with their own last asOf. The client stamps each cell, so FR-93 holds without per-cell bytes.
- Keep-alive: `{"type":"ka","seq":103,"asOf":1762412401000,"quotes":["TCS"],"chains":["NIFTY:2026-11-10"]}` every 1 s, listing items not confirmed in the last 1 s; worst case age while healthy ≈ 1.25 s (< 2 s, FR-95).
- Ticks (v1, plus frame `asOf`; `t` stays = last trade time): `{"type":"ticks","seq":104,"asOf":...,"data":[...]}`.
- Status: `{"type":"chain","seq":..,"kind":"status","chainId":"...","status":"expired","nextExpiry":"2026-11-17"}` (FR-29c).
- Clock (on welcome and on every phase change/jump): `{"type":"clock","seq":..,"serverTime":..,"marketTime":..,"marketOffsetMs":..,"phase":"open","mode":"demo","tradingDay":"2026-11-06","nextPhaseAt":..}`.
- Account channels: `{"op":"subscribe","id":3,"channel":"orders"}` and `"channel":"alerts"`. Frames: `order` `{data:{id,version,symbol,product,side,type,lots,qty,limitPrice,triggerPrice,status,avgFill,reason,updatedAt}}`, `position` `{data:{symbol,product,qty,avg,realised,dayRealised}}`, `funds` `{available}`, `settlement` `{data:{settlementId,symbol,product,qty,settlePrice,pnl,settledAt}}`, `alert` `{data:{alertId,symbol,cond,level,status,triggeredAt,triggerLtp}}`. Only sessions subscribed to the channel get them (fixes v1 broadcast to every session, incl. `ws_client`).
- Resync: `{"op":"resync","id":9}` → server sends one snapshot `ticks` + one `chain` snapshot per chain sub, all with seq > the gap. Quotes/chain resync goes over the socket (same ordered stream, no REST race); orders/positions/alerts/funds via REST, merged by `version` / `alertId`.
- `seq` is per session and covers every frame except `pong`/`ack`/`error`. AI NDJSON never touches it.

### 2.5 Server-time offset
`welcome`: `offset = serverTime − deviceNow`. Each `pong` (`ts` echoed): `rtt = now − ts`, `offset = serverTime + rtt/2 − now`; keep the sample with the lowest RTT of the last 5. `serverNow = deviceNow + offset` via injectable client `Clock`.

### 2.6 Settlement and square-off (one scheduler)
15:20: MIS positions closed at market via normal `order` frames (`reason:"auto_square_off"`). 15:30 on expiry day: open orders on expiring contracts cancelled (`expired`); every open position in them settles at intrinsic from the underlying LTP at 15:30:00.000; realised P&L and funds updated; `settlement` + `position` + `funds` frames; chain `status:expired`. `settlementId` = contract + date, so a replayed jump never settles twice. Day roll 09:00: T+1 CNC → holdings, new `prevClose`, expired contracts removed, next far expiry listed.

## 3. Message volume and conflation
| Stream | Per 250 ms flush | Rate |
|---|---|---|
| Chain 41×2 delta, LTP only (~40 B/row) | ~1.9 KB, all rows change with spot | ~7.5 KB/s, 4 frames/s |
| Chain snapshot | ~4.5 KB | on subscribe/resync only |
| Watchlist 50 in `ltp` mode (~75 B/quote) | ~3.7 KB | ~15 KB/s, 4 frames/s |
| Keep-alive | < 0.3 KB | 1 frame/s |
Worst case (chain + watchlist both subscribed) ≈ 23 KB/s, ≤ 9 frames/s; with FR-86 the covered watchlist unsubscribes, so the chain screen is ~8 KB/s. Conflation: per-session dirty sets, latest value wins; field-level diff against what this session last received; changes below one tick are not sent; IV/greeks at ≤ 1 Hz; `throttleMs` per sub (250 default, 500 for battery saver, 1000 for chat cards). Range = visible strikes ± 5 rows, client debounces scroll 150 ms. One chain frame per chain per flush; ticks and chains share one flush timer.

## 4. Client changes (interfaces only)
- `MarketSocket`: `ServerClock get serverClock` (`DateTime now()`, offset); `SocketSubscription subscribeQuotes(symbols, mode)` (v1, cap 100, options allowed for cards/positions); `ChainSubscription subscribeChain(ChainRequest)` with `updateRange(from, to)` + `cancel()`, ref-counted per `chainId` (range = union); `AccountSubscription subscribeAccount({orders, alerts})`; `Stream<SocketMessage> messages` where `SocketMessage` is a hand-written sealed family (`TicksMessage`, `ChainMessage`, `KeepAliveMessage`, `OrderMessage`, `PositionMessage`, `FundsMessage`, `SettlementMessage`, `AlertMessage`, `ClockMessage`); `Stream<void> resyncNeeded`; `DateTime? lastFrameAt` (FR-90); `Timeline` mark `frame_received(seq)` in `_onFrame`; `staleAfter` 12 s kept for reconnect only.
- `MarketRepository`: `_merge` guards on `asOf` + `seq`, never `t`; `Quote` gains `asOf`, `seq`, `fromCache`. Resync sends the socket `resync` op.
- New `ChainRepository`: `Stream<ChainView> watchChain(underlying, expiry)`, `void setVisibleRange(from, to)`, `Future<Result<List<Expiry>>> expiries(underlying)`. `ChainView` = immutable `Map<int, ChainRow>`; only changed rows get new instances (rows `select` by strike).
- New `ClockRepository` (`Stream<MarketClockState>`), `AlertsRepository` (CRUD + `Stream<Alert> triggered`), account frames into `PortfolioRepository`.
- Pure `Freshness.of(asOf, phase, socketStatus, serverNow)` → live/stale/closed, exactly §3.1; one implementation for every screen.
- Providers: manual Riverpod 3 `Provider`s for repositories and `ServerClock`; screens' controllers stay with their owners.

## 5. Interfaces with other devs
- **dev-trading:** I give `ChainRepository`/`ChainRow`/`OptionCell`, contract id format, instrument metadata (`kind, lotSize, tickSize, bandLow, bandHigh, expiry, strike, right`), `Freshness`, order body `{symbol, product, side, type, lots, limitPrice, triggerPrice}` + `Idempotency-Key`, `order`/`position`/`settlement`/`funds` frames with `version`, `clock` phase + `nextPhaseAt` for FR-37 enable-at-09:15. I need: first/last visible strike from the chain list, visibility signal to cancel subs.
- **dev-ai:** I give `packages/option_math` (`bsPrice`, `greeks`, `payoffAtExpiry`, `valueToday(iv)`), `GET /api/v1/chain` REST snapshot (same row JSON as the frame), `MarketClock` injected into the AI handler for days-to-expiry. I need: cards carry instrument ids only, live prices via `subscribeQuotes` with `throttleMs` 1000, NDJSON outside the socket.
- **dev-perf:** I give `frame_received(seq)` mark + `seq` on `Quote`/`ChainRow` for `price_painted(seq)`, `GET /debug/subscriptions`, `Quote.toJson` with `asOf`/`fromCache` for the snapshot file, `MarketSocket.start()` safe to call un-awaited after `runApp`, pause/resume unchanged. I need: lazy tabs + visibility signal (FR-82, FR-86).

## 6. Risks and rejected alternatives
| Risk | Mitigation |
|---|---|
| Clock jumps (backward, multi-day) corrupt candles/P&L | Forward replay of boundaries only; backward = reset; candles gap-filled flat across closed time |
| Theta/greeks blow up near expiry | T floor 1 min; settle at intrinsic, not BS |
| Keep-alive hides a frozen engine | Keep-alive only confirms values the engine still owns; per-symbol freeze removes them from ka and lists them in `ex` |
| Order frame lost across reconnect | `version` merge + REST reload on resync; client haptic keyed (orderId, status) |
| Rejected | Why |
|---|---|
| Per-contract quote subs for the chain | 82 subs per chain, blows the cap, churn on scroll |
| Per-cell `asOf` on the wire | ~2× bytes; frame `asOf` + `ex` gives the same meaning |
| REST for quote/chain resync | Snapshot races socket seq; socket `resync` keeps one ordered stream |
| Binary/protobuf frames | Codegen, unreadable in Socket Lab; JSON is ~8 KB/s here |
| IV solving or stochastic vol (Heston) | Cost and no user value; parametric smile is stable and testable |
| One socket per channel | Multiplies reconnect/backoff/seq state; one socket with channels |

## 7. Critiques and answers (critique round)

### Answers given
| To | Question | Answer |
|---|---|---|
| dev-ai | Option id format | `NIFTY-261110-24500-CE` (underlying-yymmdd-strike-right); same id in REST, chain frames, quote path |
| dev-ai | Options on the quote path? | Yes, they count against the cap of 100; option ticks carry `l, ch, chp, oi`, plus `iv` in full mode |
| dev-ai | Engine reads | Read-only `MarketReads` facade: `quote(id)`, `chainSnapshot(und, expiry, around)` (spot, atm, pcr, maxPain, max-OI strikes, iv), `topMovers(n, losers)`, `candles(id, 5m)`, `clock`; all stamped with wall-time `asOf` |
| dev-ai | Who owns `option_math` | dev-realtime: `bsPrice`, `greeks`, `yearsToExpiry(marketNow, expiry)`. Payoff kink maths stays in dev-ai's strategy feature. `liveQuoteProvider` autoDispose family is mine; the visibility provider is dev-perf's |
| dev-trading | Chain, order, network interfaces | Accepted as asked (see changes below) |
| dev-perf | Offset, origin, marks, linger | Accepted; offset defaults to 0 and nothing is live before `welcome` |

### Critiques sent
- **dev-trading:** (1) `asOf` arrives per frame, so if `ChainCell ==` includes `asOf`, all 82 cells rebuild on every flush and NFR-5 fails; equality should exclude `asOf`, use a chain-level `asOf` plus per-cell exceptions, and flip `isStale` only on change. (2) The REST ack and the socket `order` frame can arrive in either order; merge by `version` so Placed never goes back to Placing.
- **dev-ai:** (1) The today line must use market time (`serverNow + marketOffsetMs` from the `clock` frame), or theta disagrees with the chain under the demo clock and debug jumps. (2) `visibility_detector` is a new dependency; use a small post-frame rect check or dev-perf's `ScreenVisibility`. Server latency delays should go through the `MarketClock` delay hook.
- **dev-perf:** (1) A re-listen inside the 300 ms linger never released the server sub, so do not mark values `resumed` then; after a real resubscribe the server sends current values at once, so resumed stale lasts about one RTT. (2) Make the explicit `ScreenVisibility` the primary FR-86 signal for chain and watchlist (testable with FR-124 counts), with Riverpod `TickerMode` pausing as a bonus; save the snapshot after resync only when live.

### Changes to my design
1. Client chain API is now `watchChain(ChainRequest) → Stream<ChainUpdate>`, a sealed `ChainSnapshot{seq, spot, atm, strikes, cells by contractId}` / `ChainDelta{seq, spot, changed cells}`, with `updateRange`. The repository stamps each cell's `asOf` from the frame (or from `ex`). Scroll debounce is 250 ms (dev-trading's value).
2. `order` frames echo `clientKey` (the idempotency key). New `OrderRepository.place(req, key, timeout) → PlaceOutcome` (Acked / Rejected / TimedOut), `getOrder(id | clientKey)`, `resyncCompleted` stream, `NetworkStatus` Live / Reconnecting / Offline (Offline = socket down and a REST health probe fails).
3. `Quote.fromCache` replaced by `origin: live | cache | resumed`; `isStale(asOf, serverNow, status, phase, origin)` treats cache/resumed as stale; the repository lingers 300 ms before unsubscribing.
4. New server `market_reads.dart` (`MarketReads` facade) for the AI answer builder; `option_math` drops `payoffAtExpiry`/`valueToday` (dev-ai composes them from `bsPrice`).
5. Chain subs stay capped at 2 per session; AI chain snippets use the quote path.
