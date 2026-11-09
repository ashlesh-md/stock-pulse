# 06 · LLD: real-time server, protocol, repositories (dev-realtime)

Owner: dev-realtime · Status: **v2.0** (R-1b: CR-1 layers, CR-2 DI and typed endpoints); v1.2 (S-41 move), after LLD review (`06-lld/README.md` R1–R6, D6–D9) · Input: `04-trd.md` (TR-1…TR-11, TR-18, TR-20, TR-22, TR-25, TR-26), `05-hld.md`
§3, §5, §8, §9, §10 (§10.2 **v1.1**), ADR-0001/0002/0003/0007, PRD v1.1 §3.1/§3.2.

**v2.0 changes (R-1b, HLD v2.1 §4, ADR-0009/0010/0014/0020, CR-2 rules 1 and 18)**
- `core/network/` and `core/market_time/` are layered `domain/ data/ application/ di/` (table §1.3). DI files live in
  `di/` (CR-2 rule 1): `core/network/di/network_providers.dart`, `core/market_time/di/market_time_providers.dart`,
  `features/<f>/di/<f>_data_providers.dart` for market, options, orders, portfolio, alerts. `networkStatusProvider`
  moved from market_time to `core/network/application/`.
- Typed REST (CR-2 rule 18): `core/network/domain/endpoint.dart` (`Endpoint.get/post/delete`, `HttpMethod`);
  `ApiClient.call(Endpoint)` replaces `get/post/delete(String)`; `ApiClient.uriOf(Endpoint)` replaces `resolve(String)`.
  Endpoints per feature in `features/<f>/data/<f>_api.dart`; core ones (health, debug) in `core/network/data/core_api.dart`.
- Typed socket ops: `core/network/domain/socket_ops.dart` (sealed `SocketOp`: `SubscribeQuotes`, `UnsubscribeQuotes`,
  `SubscribeChannel`, `UnsubscribeChannel`, `Ping`; `AccountChannel`). `SubscriptionBook.pendingOps()` returns them.
- `market_socket.dart` split: `data/market_socket.dart` (connection, heartbeat, reconnect), `data/frame_decoder.dart`
  (`frameText`, `decodeFrame`, `SequenceGapDetector`), `data/subscription_book.dart` (ref counts, diff to server),
  `data/socket_config.dart`, `domain/socket_status.dart`. `MarketSocket.subscribe` alias removed (use `subscribeQuotes`).
- Deviation: `ChainRequest` moved to `core/network/domain/chain_request.dart` and `ChainStatus` to
  `core/network/domain/socket_messages.dart`, because core may not import features (ADR-0010) and the socket parses both.
  `features/options` imports them from there. `DebugClient` interface in `domain/`, `HttpDebugClient` in `data/`.
- Old paths (`core/network/{providers,market_socket,network_status,network_providers}.dart`,
  `core/market_time/{providers,clock,market_clock_state,freshness,market_time_providers}.dart`,
  `features/<f>/<f>_providers.dart`) are export-only shims so other owners' files compile mid-wave; deleted at the W1R
  checkpoint once importers move.
- Server splits (≤ 300 lines): `market_engine.dart` → `stock_state.dart` (`StockState`, `FeedMode`, `toQuoteJson`),
  `candle_math.dart` (`roundToTick`, `gaussian`, `addToCandles`, `aggregateCandles`), `history_seed.dart`;
  `ws_gateway.dart` → parts `ws_session.dart`, `ws_session_ops.dart` (`idleCheckNow()`, `maxQuotes` now a constructor
  field); `instruments.dart` → `instrument_table.dart` (compact constituent rows). Tests split: `protocol_v2_test.dart`
  + `protocol_v2_flow_test.dart` over `test/support/protocol_rig.dart`; `market_test.dart` + `broker_test.dart` over
  `test/support/engine_fixture.dart`.
- Bug fixed test-first: `POST /api/v1/orders` with a JSON array body returned 500; now 400 `invalid_json`.
**v1.1 changes**
- R1: `ChainRead` gains `strikeStep` (§3.8).
- R2: I own `core/network/api_client.dart` and add `send(http.BaseRequest)`, which adds the auth header; `postLines` moves to dev-ai's `api_client_lines.dart` extension (§1.3, §7.6).
- R3: `MarketRepository.watchlistIds` / `setWatchlist` (calls `markStructuralDirty`) / `latestQuotes`; `PortfolioBook` + `PortfolioRepository.current`; `Position`/`Holding` `toJson`/`fromJson` (§7.4, §7.5).
- R4: `DebugClient` (`setClock`, `reset`) and the debug clock screen's backward-preset confirm (§7.6).
- R5: FR-110 traced: Socket Lab ring capped at 500 frames, under More › Developer (§7.6, §9.4).
- R6: the `option_math.dart` barrel is owned by dev-realtime (§1.1).
- D6–D9 recorded where used: chain throttle fixed at 250 ms, `OptionCell.iv`/`delta` always populated (≤ 1 Hz), backward jump 409 + reset, `place` = one attempt, `ka` re-emits equal quotes.
**v1.2 changes**
- S-41 move (architect-approved, HLD §4): the debug clock screen and Socket Lab UI (`features/more/{debug_clock,socket_lab}/`), their file rows (§1.3) and tests `debug_clock_controller_test` / `socket_lab_test` (§9.4) now live in `perf.md` (§7.1, T27–T28). Kept here: `DebugClient`, `MarketSocket.frames`, `/debug/*` (§6, §7.3, §7.6).

Covers (HLD §10.1): server modules in HLD §3 except `ai/`, the socket protocol, `MarketClock`/calendar/scheduler, pricing,
settlement, debug hooks FR-120…124, client `MarketSocket`, `ServerClock`, `freshnessOf`, every repository except AI/strategy,
and `option_math/pricing.dart`.
Rules: Dart stdlib + existing deps only; manual Riverpod 3 providers; hand-written immutable classes with `==`/`hashCode`/
`copyWith`/`fromJson`/`toJson`; no codegen. Interfaces marked **§10.2** are quoted verbatim from the HLD and are binding.

---

## 1. File layout

### 1.1 `packages/option_math/` (new, pure Dart, no Flutter import)
| File | Owner | Contents |
|---|---|---|
| `lib/option_math.dart` | dev-realtime (R6) | barrel only: exports `pricing.dart`, `payoff.dart` |
| `lib/src/pricing.dart` | dev-realtime | `OptionRight`, `Greeks`, `bsPrice`, `greeks`, `yearsToExpiry`, `normCdf`, `normPdf` |
| `lib/src/payoff.dart` | dev-ai | `PayoffLeg`, `PayoffSummary`, `payoffAtExpiry`, `payoffSummary`, `valueToday` (see `06-lld/ai.md`) |
| `test/pricing_test.dart` | dev-realtime | §9.1 |

### 1.2 `market_server/lib/src/`
| File | Status | Main types |
|---|---|---|
| `ist.dart` | new | `IstDate` (y, m, d value type), `Ist.toIst`, `Ist.at(IstDate, h, m, [s, ms]) → DateTime (UTC)`; IST = UTC+05:30 fixed |
| `market_clock.dart` | new | `ClockMode`, `MarketClock`, `FakeMarketClock`, `ClockJump` |
| `market_calendar.dart` | new | `MarketPhase`, `ExpiryKind`, `ListedExpiry`, `MarketCalendar`, `nseHolidays2026` table |
| `clock_scheduler.dart` | new | `BoundaryKind`, `BoundaryEvent`, `ClockScheduler` |
| `instruments.dart` | changed | 50 equities + NIFTY (`InstrumentKind`), `underlyingConfigs` |
| `models.dart` | changed | `Instrument` (+ kind, band, strikeStep, expiry, strike, right, underlying), `Order` (+ product, lots, triggerPrice, clientKey, version, reason), `Position` (+ product, version), `Holding`, `Funds`, `PriceAlert`, `Settlement` |
| `tradable.dart` | new | `Tradable` interface implemented by `StockState` and `OptionState` |
| `option_instruments.dart` | new | `OptionContract`, `OptionChainDef`, `OptionUniverse` |
| `option_pricer.dart` | new | `VolModel`, `OptionState`, `OptionPricer` |
| `chain_book.dart` | new | `CellWire`, `ChainBook` (per-session diff helper) |
| `market_engine.dart` | changed | phase-aware `step()`, IEP, `optionPricer`, `Tradable? operator [](id)` |
| `broker.dart` | changed | (symbol, product) positions, holdings, funds, SL, phase rules, square-off, `version` |
| `expiry_service.dart` | new | settlement, delisting, `chain status` events |
| `alerts_engine.dart` | new | crossing detection, one-shot alerts |
| `market_reads.dart` | new | `MarketReads` read-only facade for `ai/` (dev-ai) |
| `ws_gateway.dart` | changed | channels, flush, `ka`, `resync`, caps, freeze, account routing |
| `rest_api.dart` | changed | new routes §5 |
| `debug_api.dart` | new | `/debug/*` routes, `FaultInjector`, `faultInjection()` middleware |
| `../market_server.dart` | changed | wires all of the above; `MarketServer({MarketClock? clock, Random? random, bool debug, ...})` |
| `../../bin/server.dart` | changed | flags `--port`, `--latency-ms`, `--clock=demo|real` (default demo), `--debug` (default on in demo), `--seed` |

### 1.3 `stock_pulse/lib/` (v2.0)
| Path | Layer | Main types |
|---|---|---|
| `core/market_time/domain/clock.dart` · `server_clock.dart` · `market_clock_state.dart` · `freshness.dart` | domain | `Clock`, `SystemClock`, `FakeClock`, `ServerClock`, `MarketPhase`, `MarketClockState`, `Freshness`, `kStaleAfter`, `freshnessOf` |
| `core/market_time/data/clock_repository.dart` | data | `ClockRepository` |
| `core/market_time/application/market_clock_provider.dart` · `freshness_tick_provider.dart` | application | `marketClockProvider`, `freshnessTickProvider` |
| `core/market_time/di/market_time_providers.dart` | DI | `clockProvider`, `serverClockProvider`, `clockRepositoryProvider` |
| `core/network/domain/socket_messages.dart` | domain | sealed `SocketMessage` family, `ChainFrameKind`, `ChainStatus` |
| `core/network/domain/socket_status.dart` · `subscriptions.dart` · `network_status.dart` | domain | `SocketStatus` family, `SocketFrame`, `FeedMode`, `SocketSubscription`, `ChainSubscription`, `AccountSubscription`, `NetworkStatus` |
| `core/network/domain/chain_request.dart` · `endpoint.dart` · `socket_ops.dart` · `debug_client.dart` | domain | `ChainRequest`, `Endpoint`, `HttpMethod`, `SocketOp` family, `AccountChannel`, `DebugClient` |
| `core/network/data/market_socket.dart` · `socket_config.dart` · `frame_decoder.dart` · `subscription_book.dart` | data | `MarketSocket`, `SocketConfig`, `frameText`, `decodeFrame`, `SequenceGapDetector`, `SubscriptionBook` |
| `core/network/data/api_client.dart` · `core_api.dart` · `http_debug_client.dart` · `backoff.dart` · `resync_coordinator.dart` | data | `ApiClient.call(Endpoint)`, `send`, `uriOf`, `getHealth`; `healthEndpoint`, `setClockEndpoint`, `resetEndpoint`; `HttpDebugClient`; `reconnectDelay`; `ResyncCoordinator` |
| `core/network/data/api_client_lines.dart` | data (dev-ai) | `extension ApiClientLines` |
| `core/network/application/socket_status_provider.dart` · `network_status_provider.dart` | application | `socketStatusProvider`, `networkStatusProvider` |
| `core/network/di/network_providers.dart` | DI | `appConfigProvider`, `apiClientProvider`, `marketSocketProvider`, `debugClientProvider` |
| `core/error/result.dart` · `app_error.dart` | flat | `Result`, `Success`, `Failure`, `parseJson`, `AppError` family |
| `features/market/domain/` | domain | `Quote`, `Instrument`, `Candle`, `CandleInterval`, `ChartRange`, `MarketRepository` |
| `features/market/data/live_market_repository.dart` · `market_api.dart` | data | `LiveMarketRepository`; `instrumentsEndpoint`, `quotesEndpoint`, `candlesEndpoint` |
| `features/market/application/live_quote_provider.dart` | application | `liveQuoteProvider` |
| `features/options/domain/` · `data/live_chain_repository.dart` | domain · data | `OptionCell`, `ChainRow`, `ChainView`, `Expiry`, `ChainFeed`, `ChainRepository`; `LiveChainRepository` |
| `features/orders/domain/` · `data/live_order_repository.dart` · `data/orders_api.dart` | domain · data | `Order`, `OrderRequest`, `PlaceOutcome`, `OrderRepository`; `LiveOrderRepository`; `ordersEndpoint`, `orderEndpoint`, `cancelOrderEndpoint`, `placeOrderEndpoint` |
| `features/portfolio/domain/` · `data/live_portfolio_repository.dart` · `data/portfolio_api.dart` | domain · data | `Position`, `Holding`, `Funds`, `Settlement`, `PortfolioBook`, `PortfolioRepository`; `LivePortfolioRepository`; `positionsEndpoint` |
| `features/alerts/domain/` · `data/live_alerts_repository.dart` | domain · data | `PriceAlert`, `AlertsRepository`; `LiveAlertsRepository` |
| `features/<f>/di/<f>_data_providers.dart` (market, options, orders, portfolio, alerts) | DI | repository providers typed as the domain interface |

---

## 2. Option maths: `packages/option_math/lib/src/pricing.dart`

```dart
enum OptionRight { ce, pe }
class Greeks { const Greeks({required this.delta, required this.gamma, required this.theta, required this.vega});
  final double delta;  // per 1 ₹ of spot
  final double gamma;  // per 1 ₹ of spot
  final double theta;  // ₹ per unit per calendar day (negative for long options)
  final double vega;   // ₹ per unit per 1 vol point (0.01)
}
double bsPrice({required OptionRight right, required double spot, required double strike,
  required double years, required double iv, double rate = 0.065});                       // §10.2
Greeks greeks({required OptionRight right, required double spot, required double strike,
  required double years, required double iv, double rate = 0.065});                       // §10.2 "...same args"
double yearsToExpiry(DateTime marketNow, DateTime expiryAt);                               // §10.2
double normCdf(double x);  double normPdf(double x);
```
- `yearsToExpiry` = `max(0, expiryAt − marketNow)` in ms / (365 × 86 400 000). Calendar time; both args are **market** time (ADR-0002).
- `bsPrice`: if `years <= 0` or `iv <= 0` → intrinsic (`max(S−K,0)` / `max(K−S,0)`). Else `d1 = (ln(S/K) + (r + iv²/2)·T) / (iv·√T)`,
  `d2 = d1 − iv·√T`; CE = `S·N(d1) − K·e^(−rT)·N(d2)`; PE = `K·e^(−rT)·N(−d2) − S·N(−d1)`. No dividend (q = 0).
- `greeks`: Δ CE `N(d1)`, PE `N(d1) − 1`; Γ `n(d1)/(S·iv·√T)`; Θ CE `(−S·n(d1)·iv/(2√T) − r·K·e^(−rT)·N(d2)) / 365`, PE
  `(−S·n(d1)·iv/(2√T) + r·K·e^(−rT)·N(−d2)) / 365`; Vega `S·n(d1)·√T / 100`. `years <= 0` → Δ ∈ {0, ±1} by moneyness, others 0.
- `normCdf`: Abramowitz–Stegun 26.2.17 (|error| < 7.5e-8); `normPdf` exact. No allocation, no `Random`.
- The smile, OU drift and T floor are **not** in the package (ADR-0007); they live in `option_pricer.dart`.

---

## 3. Server design

### 3.1 Time: `ist.dart`, `market_clock.dart`
```dart
enum ClockMode { demo, real }
class ClockJump { const ClockJump(this.fromMarket, this.toMarket); final DateTime fromMarket, toMarket; }
class MarketClock {
  MarketClock({required this.mode, DateTime Function()? wall, Duration initialOffset = Duration.zero});
  final ClockMode mode;
  DateTime wallNow();                          // UTC wall time: serverTime, asOf, staleness, ka, idle timers
  DateTime marketNow();                        // wallNow() + marketOffset: phase, candles, expiry, T, order times
  Duration get marketOffset;
  bool get overridden;                         // true in demo mode or after any jumpTo → "Demo clock" chip
  void jumpTo(DateTime marketTime);            // offset = marketTime − wallNow(); emits on jumps
  Stream<ClockJump> get jumps;                 // sync broadcast
  Future<void> delay(Duration d);              // real: Future.delayed; fake: completes on advance
  static MarketClock demo(MarketCalendar cal, {DateTime Function()? wall}); // market 10:00:00 IST today or next trading day
}
class FakeMarketClock extends MarketClock {     // tests (FR-120)
  FakeMarketClock({required DateTime wallStart, DateTime? marketStart});
  void advance(Duration d);                    // moves wall (market follows), completes due delay() futures in order
}
```
Gateway and engine keep real `Timer.periodic`; every callback reads the clock, so tests drive them with
`engine.step()`, `scheduler.tick()`, `gateway.flushNow()`, `gateway.keepAliveNow()` plus `FakeMarketClock.advance` (no waiting).

### 3.2 Calendar: `market_calendar.dart` (pure; no clock inside)
```dart
enum MarketPhase { preOpen, open, closed }
enum ExpiryKind { weekly, monthly }
class ListedExpiry { final IstDate date; final DateTime expiryAt; final ExpiryKind kind; String get code; } // code "2026-11-10"
class MarketCalendar {
  MarketCalendar({required Set<IstDate> holidays, required String holidaySourceDate});
  bool isTradingDay(IstDate d);                // Mon–Fri and not a holiday
  MarketPhase phaseAt(DateTime utc);           // [09:00, 09:15) preOpen · [09:15, 15:30) open · else closed
  DateTime? nextPhaseChangeAfter(DateTime utc);// next 09:00 / 09:15 / 15:30 on a trading day
  IstDate nextTradingDay(IstDate d);  IstDate previousTradingDay(IstDate d);
  IstDate adjustForHoliday(IstDate expiry);    // holiday → previous trading day (repeat)
  List<ListedExpiry> expiriesFor(String underlying, IstDate day, {int count = 2});
}
```
`expiriesFor`: NIFTY → candidate Tuesdays from `day` onward (weekly), stocks → last Tuesday of this and following months
(monthly); each `adjustForHoliday`; keep the first `count` whose adjusted date ≥ `day`; `expiryAt = Ist.at(date, 15, 30)`.
The holiday table is one `const` map with `holidaySourceDate`; tests pass their own set (FR-24 fixture: Tuesday holiday → Monday).

### 3.3 Scheduler: `clock_scheduler.dart`
```dart
enum BoundaryKind { dayRoll, open, squareOff, settle, close }   // 09:00, 09:15, 15:20, 15:30 (settle before close)
class BoundaryEvent { final BoundaryKind kind; final IstDate tradingDay; final DateTime at; String get key; } // "settle@2026-11-10"
class ClockScheduler {
  ClockScheduler(MarketClock clock, MarketCalendar calendar);
  void on(BoundaryKind kind, void Function(BoundaryEvent e) handler);   // handlers run in registration order
  void tick();                         // called by the engine timer every step and right after a jump
  DateTime get lastProcessed;          // market time
  void resetTo(DateTime marketTime);   // /debug/reset only: clears processed keys, lastProcessed = marketTime
  Stream<MarketPhase> get phaseChanges;
}
```
Algorithm of `tick()`:
1. `now = clock.marketNow()`. If `now <= lastProcessed` → return (backward jumps are refused by `/debug/clock`, see §6).
2. Enumerate trading days from `lastProcessed`'s IST date to `now`'s; if more than **10** trading days, set `lastProcessed` to
   09:00 of the 10th-last trading day and fire one `dayRoll` with `fastForward: true` for the skipped span (flat daily candles).
3. For each trading day, for each boundary in time order, if `lastProcessed < at <= now` and `key` not in `_processed`:
   add key, call handlers with `e`. `settle` fires only when any listed expiry date == that day.
4. `lastProcessed = now`; emit `phaseChanges` when `calendar.phaseAt(now)` differs from the last emitted phase.
`_processed` keeps keys of the last 20 trading days. Handlers registered in `MarketServer`, in this order:

| Boundary | Handlers (order) |
|---|---|
| `dayRoll` | engine `rollDay` (close daily candles, new `prevClose`, flat candles on fast-forward) → `OptionUniverse.rebuildForDay` (drop expired, list new far expiry, new 41-strike sets) → broker `rollDay` (T+1 CNC → holdings, day P&L reset) → alerts (none) |
| `open` | engine `openMarket` (IEP becomes open price) → broker `fillQueuedPreOpen` |
| `squareOff` | broker `squareOffMis` |
| `settle` | `ExpiryService.settle(day)` |
| `close` | broker `expireDayOrders` (open/trigger-pending orders → `cancelled`, reason `market_closed`) |
Every phase change and every jump → gateway broadcasts a `clock` frame to all sessions.

### 3.4 Instruments and options: `instruments.dart`, `option_instruments.dart`
```dart
enum InstrumentKind { index, equity, option }
class UnderlyingConfig { final String symbol; final int strikeStep, lotSize; final ExpiryKind expiryKind;
  final double baseAtmIv, skew, curv; }
const underlyingConfigs = { 'NIFTY': UnderlyingConfig(50, 65, weekly, 0.13, -0.12, 0.04),
  'RELIANCE': UnderlyingConfig(10, 500, monthly, 0.22, -0.08, 0.04), 'HDFCBANK': UnderlyingConfig(10, 550, monthly, 0.20, -0.08, 0.04) };
class OptionContract { final String id; final String underlying; final ListedExpiry expiry; final int strike;
  final OptionRight right; final int lotSize; final double tickSize; }      // id "NIFTY-261110-24500-CE" (TR-25)
class OptionChainDef { final String chainId; final String underlying; final ListedExpiry expiry; final int step;
  final List<int> strikes; }                                                // chainId "NIFTY:2026-11-10", 41 strikes ascending
class OptionUniverse {
  Iterable<OptionChainDef> get chains;   OptionChainDef? chain(String chainId);
  OptionContract? operator [](String id);  List<ListedExpiry> expiries(String underlying);
  void rebuildForDay(IstDate day, Map<String, double> prevCloseByUnderlying, {required Set<String> pinned});
}
```
- Strike set per (underlying, expiry) per day: `centre = round(prevClose / step) · step`; strikes `centre ± 20·step`. Never
  re-centred intraday (FR-20). ATM is computed per flush as the strike nearest spot (ties → lower strike).
- `pinned` = contract ids referenced by an open position, open order or active alert; pinned contracts outside the new strike
  set stay priced and quotable but are not chain rows. Expired contracts are removed after settlement even if referenced.
- Instrument metadata (TR-25): equities band ±20 % of prevClose, tick 0.05, lot 1; options `bandLow = 0.05`,
  `bandHigh = 3 × prevClose` (FR-34), tick 0.05, lot from config; index has no band and is not tradable.
- `instruments.dart`: 50 NIFTY-50 names with base prices and a liquidity weight (v1 12 kept), plus `NIFTY` (index, price =
  weighted sum normalised to ~24 600 at seed). Seeded `Random(seed)` for reproducible tests.

### 3.5 Engine and pricer: `market_engine.dart`, `option_pricer.dart`
```dart
abstract interface class Tradable { String get id; InstrumentKind get kind; double get ltp; double get prevClose;
  double get change; double get changePercent; DateTime get lastTradeTime; }
class OptionState implements Tradable { final OptionContract contract; double ltp; double prevClose; int oi; int oiAtOpen;
  int volume; double iv; double delta; DateTime greeksAt; DateTime lastTradeTime; int get oiChange => oi - oiAtOpen; }
class VolModel { double atmIv(String underlying); void step(Random r);
  double ivFor(UnderlyingConfig c, {required double strike, required double forward, required double years}); }
class OptionPricer {
  OptionPricer(OptionUniverse universe, VolModel vol, MarketClock clock);
  Set<String> repriceFor(Set<String> underlyingsThatTicked, Map<String, double> spot, Random r); // returns changed contract ids
  OptionState? operator [](String contractId);
  void freezeForPreOpen(bool frozen);
}
```
- `MarketEngine.step()` reads `phase = calendar.phaseAt(clock.marketNow())`: **closed** → nothing trades, return;
  **preOpen** → equities only, IEP walk with σ × 0.3, no volume, no minute candles, quote field `iep: true`; options frozen;
  **open** → v1 random walk for equities, NIFTY recomputed from constituents, then `optionPricer.repriceFor(...)`.
  `ticks` stream emits all changed ids (equities, index, contracts). Candles use **market** time.
- Vol model: per underlying `atm += 0.002·(base − atm) + 0.0004·N(0,1)` per step (OU), clamped to [0.5, 2] × base.
  `atm(T) = atm·(1 + 0.15·e^(−T/0.05))`; `m = ln(K/F)/√max(T, 1/365)`, `F = S·e^(rT)`;
  `iv = clamp(atm(T)·(1 + skew·m + curv·m²), 0.05, 1.5)`.
- Price: `years = max(yearsToExpiry(marketNow, expiryAt), 1 min in years)` (TR-26); `p = bsPrice(...)`, rounded to 0.05,
  min 0.05. Changed when the rounded price differs: set `ltp`, `lastTradeTime`, add random volume (multiples of lot).
  OI: with p = 0.1 per step, `oi += lot · round(N(0, 3))`, ≥ 0. Seed OI at listing: `lot · 4000 · e^(−|K−S|/(6·step))`,
  calls skewed above spot, puts below. `iv`/`delta` recomputed at most every 1 s (wall) per contract (`greeksAt`).
- At listing / day roll: option `prevClose` = previous ltp, or BS at 09:00 for a new listing; `oiAtOpen = oi`.
- Cost: ≤ 500 contracts × 1 BS per step < 1 ms (benchmark test §9.2).

### 3.6 Chain diff: `chain_book.dart`
```dart
class CellWire { final double l, ch; final int oi, d; final double? iv, dl;  Map<String, Object?> diff(CellWire? prev, {required bool withGreeks}); }
class ChainBook {  // one per (session, chain sub)
  ChainBook(OptionChainDef def, {required int fromStrike, required int toStrike, required int throttleMs});
  int fromStrike, toStrike, throttleMs;  DateTime? lastFlushAt, lastGreeksAt;
  final Map<String, CellWire> lastSent;                    // contractId → what this session last received
  List<int> setRange(int from, int to);                    // clamps to def.strikes; returns newly added strikes
  Map<String, Object?> snapshotJson(OptionPricer p, {List<int>? only, required DateTime asOf, required Set<String> frozen});
  Map<String, Object?>? deltaJson(OptionPricer p, {required DateTime asOf, required Set<String> frozen});
}
```
`deltaJson`: for each strike in range and each right, build `CellWire` from `OptionState`; skip frozen ids (→ `ex`); put
fields that differ from `lastSent` (`iv`, `dl` only when `wallNow − lastGreeksAt ≥ 1 s`); update `lastSent`. Returns `null`
when no row, no `spot` change and no `atm` change (the chain is then confirmed by `ka`). Strikes leaving the range are removed
from `lastSent`, so re-entry gets a fresh partial snapshot.

### 3.7 Broker, expiry, alerts
```dart
enum ProductType { cnc, mis, nrml }
enum OrderType { market, limit, sl }
enum OrderStatus { queued, open, triggerPending, complete, cancelled, rejected }   // v1 values kept; queued = pre-open limit
class Broker {
  Broker(MarketEngine engine, MarketClock clock, MarketCalendar calendar, {double startingFunds = 1000000});
  Order place({required String symbol, required OrderSide side, required OrderType type, required ProductType product,
    int? quantity, int? lots, double? limitPrice, double? triggerPrice, String? idempotencyKey});   // throws OrderRejection
  Order cancel(String id);  Order? byId(String id);  Order? byClientKey(String key);
  List<Order> get orders;  List<Position> get positions;  List<Holding> get holdings;  Funds get funds;
  Stream<AccountEvent> get events;            // sealed: OrderEvent, PositionEvent, FundsEvent, SettlementEvent
  void rollDay(BoundaryEvent e); void fillQueuedPreOpen(BoundaryEvent e); void squareOffMis(BoundaryEvent e);
  void expireDayOrders(BoundaryEvent e); void settleContract(OptionContract c, double settlePrice, IstDate day);
  void reset();
}
```
`place` validation order (first failure throws `OrderRejection(code, message, status)`):
1. Idempotency: key seen → return the stored order (HTTP 200, no new event).
2. Instrument: unknown → `unknown_symbol` 404; index → `not_tradable`; expired contract → `contract_expired`.
3. Product: equity ∈ {cnc, mis}, option ∈ {mis, nrml} else `invalid_product`.
4. Quantity: option needs `lots ≥ 1` (quantity = lots × lotSize); equity `quantity ≥ 1`; else `invalid_quantity`.
5. Phase (FR-37): closed → `market_closed`; preOpen → only equity `limit` allowed (stored `queued`), else `preopen_not_allowed`.
6. Price: limit/trigger multiple of tick → else `tick_size`; inside [bandLow, bandHigh] → else `price_band` (message has range);
   SL buy `trigger ≤ limit`, sell `trigger ≥ limit` → else `invalid_trigger`.
7. Funds (FR-39): buy value `qty × (limit ?? ltp)` > `funds.available` → `insufficient_funds`. CNC sell qty > held
   (holdings + today's CNC net) → `insufficient_holdings` (FR-39a). Short options allowed.
8. Create with `version = ++_version`, `clientKey = idempotencyKey`; market orders fill immediately at ltp; limit fills when
   ltp crosses; SL becomes `open` limit when ltp touches trigger.
Fill: position key `"$symbol|$product"`; buy debits `qty × price`, sell credits; every mutation bumps the global `_version` and
stamps the touched order/position/funds; one `AccountEvent` each. `squareOffMis`: cancel open MIS orders, then a market order
opposite each MIS position (`reason: "auto_square_off"`, no clientKey). `rollDay`: CNC net buys → holdings (weighted avg),
CNC sells already reduced holdings at fill; MIS rows removed (qty 0); NRML rows carry over with `dayRealised = 0`.

`expiry_service.dart` — `settle(IstDate day)` for each chain whose expiry date == day:
1. Cancel open orders on its contracts (`reason: "expired"`).
2. For each position in a contract of the chain with qty ≠ 0: `settlePrice = intrinsic(underlying ltp at the event)`;
   `settlementId = "$contractId@$day"`; if already in `_settled` → skip (jump replays, HLD §9); else
   `broker.settleContract(...)`: realised `+= (settlePrice − avg) × qty` (signed), funds `+= settlePrice × qty`, qty → 0.
3. Emit `SettlementEvent` per position and a `ChainStatusEvent(chainId, expired, nextExpiry)`; the chain stays priced at
   intrinsic until the next `dayRoll` removes it. FR-49 example: long 1 lot (65) 24500 CE, spot 24600 → settle 100 → ₹6,500.

`alerts_engine.dart`:
```dart
enum AlertCondition { above, below }
enum AlertStatus { active, triggered, cancelled }
class AlertsEngine { AlertsEngine(MarketEngine engine, MarketClock clock);
  PriceAlert create({required String symbol, required AlertCondition cond, required double level});   // throws AlertRejection
  PriceAlert delete(String alertId);  List<PriceAlert> get all;  Stream<PriceAlert> get triggered;  void reset(); }
```
On every `ticks` event, for active alerts of changed ids: `above` fires when `prev < level && ltp >= level`; `below` when
`prev > level && ltp <= level` (`prev` = ltp before this step, kept per id). Fire once: status `triggered`, `triggeredAt`
(market time, ISO), `triggerLtp`, `version++`. Create rejects `unknown_symbol`, `invalid_level` (≤ 0 or not a tick multiple),
and `condition_already_met` (level already crossed at creation), all 422.

### 3.8 `market_reads.dart` (facade for dev-ai)
```dart
class QuoteRead { final String id; final InstrumentKind kind; final double ltp, change, changePct, prevClose; final DateTime asOf; }
class ChainCellRead { final String id; final double ltp; final int oi; final double iv; }
class ChainRowRead { final int strike; final ChainCellRead ce, pe; }
class ChainRead { final String underlying, expiry; final DateTime expiryAt, asOf; final double spot, pcr; final int atm,
  strikeStep, lotSize, maxPain, maxCallOiStrike, maxPutOiStrike; final List<ChainRowRead> rows; }   // strikeStep: v1.1 (R1)
abstract interface class MarketReads {
  DateTime wallNow(); DateTime marketNow(); MarketPhase phase();
  Instrument? instrument(String idOrAlias);  List<Instrument> instruments();
  QuoteRead? quote(String id);
  ChainRead? chainSnapshot(String underlying, {String? expiry, int around = 2});   // expiry null = nearest
  List<String> expiries(String underlying);
  List<QuoteRead> topMovers(int n, {bool losers = false});                       // equities only, by changePct
  List<Candle> candles(String id, Duration interval, {int limit = 75});
}
```
`asOf` = `wallNow()` at the read. PCR = Σ put OI / Σ call OI over all 41 strikes; max pain = strike K* minimising
Σ callOI·max(K*−K, 0) + putOI·max(K−K*, 0). Read-only: no method mutates state (architecture test: `ai/` imports only this).

---

## 4. Socket protocol v2 (`ws_gateway.dart`)

Session state: `seq`, `lastHeard` (wall), `Map<String, QuoteSub> quotes` (mode, throttleMs, lastSentAt, lastConfirmedAt),
`Map<String, ChainBook> chains` (+ `lastConfirmedAt`), `bool ordersSub, alertsSub`, `Set<String> pendingQuotes`.
Gateway state: `Map<String, DateTime> frozenUntil` (per id, wall), v1 socket-wide freeze, `skipSequence()`.
Timers: flush **250 ms** (`flushNow()`), keep-alive **1 s** (`keepAliveNow()`), idle check 5 s (v1). Caps: 100 quote ids,
2 chain subs per session. `seq` +1 on every frame except `pong`, `ack`, `error`. All times are ms since epoch;
`serverTime`/`asOf` are **wall** UTC, `marketTime`/`createdAt`/`updatedAt`/`triggeredAt` are **market** time.

### 4.1 Client → server
```json
{"op":"subscribe","id":1,"channel":"quotes","symbols":["RELIANCE","NIFTY-261110-24500-CE"],"mode":"quote","throttleMs":250}
{"op":"unsubscribe","id":2,"channel":"quotes","symbols":["RELIANCE"]}
{"op":"subscribe","id":3,"channel":"chain","underlying":"NIFTY","expiry":"2026-11-10","fromStrike":24100,"toStrike":25100}
{"op":"unsubscribe","id":4,"channel":"chain","chainId":"NIFTY:2026-11-10"}
{"op":"subscribe","id":5,"channel":"orders"}      {"op":"subscribe","id":6,"channel":"alerts"}
{"op":"resync","id":7}
{"op":"ping","ts":1762412400000}
```
- `channel` missing → `quotes` (v1 clients and `bin/ws_client.dart` keep working). `mode` ∈ ltp/quote/full, default quote.
- Re-subscribing an id or a chain replaces its mode/throttle/range. Chain `throttleMs` is fixed at 250 (the §10.2
  `ChainRequest` has no throttle or fields); IV and delta are always sent, at ≤ 1 Hz.

### 4.2 Server → client
```json
{"type":"welcome","sessionId":"S4","serverTime":1762412400000,"flushMs":250,"keepAliveMs":1000,"idleTimeoutMs":30000,
 "clock":{"serverTime":1762412400000,"marketTime":1762416000000,"marketOffsetMs":3600000,"phase":"open","mode":"demo",
          "overridden":true,"tradingDay":"2026-11-06","nextPhaseAt":1762422000000}}
{"type":"ack","id":1,"op":"subscribe","channel":"quotes","symbols":["RELIANCE","NIFTY-261110-24500-CE"],"mode":"quote","throttleMs":250}
{"type":"ack","id":3,"op":"subscribe","channel":"chain","chainId":"NIFTY:2026-11-10","strikes":[23600,24600,50],"lotSize":65,
 "expiryAt":1762768800000,"fromStrike":24100,"toStrike":25100}
{"type":"ticks","seq":100,"asOf":1762412400250,"data":[{"s":"RELIANCE","ltp":1412.35,"ch":8.1,"chp":0.58,"t":1762412400190,
 "o":1404.0,"h":1415.2,"l":1401.1,"pc":1404.25,"v":3021400,"lq":25,"bid":1412.3,"ask":1412.4}],"ex":{"TCS":1762412391000}}
{"type":"chain","seq":101,"kind":"snapshot","chainId":"NIFTY:2026-11-10","asOf":1762412400250,"spot":24612.35,"atm":24600,
 "status":"open","partial":false,"rows":[{"k":24600,"c":{"l":112.4,"ch":-6.2,"oi":4521300,"d":12300,"iv":13.42,"dl":0.521},
 "p":{"l":98.1,"ch":4.0,"oi":3980100,"d":-4100,"iv":13.95,"dl":-0.479}}]}
{"type":"chain","seq":102,"kind":"delta","chainId":"NIFTY:2026-11-10","asOf":1762412400500,"spot":24613.1,
 "rows":[{"k":24600,"c":{"l":112.45}},{"k":24650,"p":{"l":121.3,"ch":5.1}}],"ex":{"NIFTY-261110-24700-CE":1762412395000}}
{"type":"chain","seq":140,"kind":"status","chainId":"NIFTY:2026-11-10","asOf":1762768800010,"status":"expired","nextExpiry":"2026-11-17"}
{"type":"ka","seq":103,"asOf":1762412401000,"quotes":["TCS","INFY"],"chains":[]}
{"type":"clock","seq":104,"serverTime":...,"marketTime":...,"marketOffsetMs":...,"phase":"closed","mode":"demo","overridden":true,
 "tradingDay":"2026-11-06","nextPhaseAt":...}
{"type":"order","seq":105,"asOf":...,"data":{"id":"O12","clientKey":"7f3c…","version":41,"symbol":"NIFTY-261110-24500-CE",
 "product":"nrml","side":"buy","type":"limit","lots":2,"quantity":130,"limitPrice":110.0,"triggerPrice":null,"status":"complete",
 "averagePrice":109.95,"reason":null,"message":"Filled at 109.95","createdAt":"2026-11-06T10:02:11.000+05:30","updatedAt":"…"}}
{"type":"position","seq":106,"asOf":...,"data":{"symbol":"NIFTY-261110-24500-CE","product":"nrml","quantity":130,"lots":2,
 "averagePrice":109.95,"realizedPnl":0.0,"dayRealizedPnl":0.0,"version":42}}
{"type":"funds","seq":107,"asOf":...,"data":{"available":985706.5,"version":43}}
{"type":"settlement","seq":141,"asOf":...,"data":{"settlementId":"NIFTY-261110-24500-CE@2026-11-10","symbol":"…","product":"nrml",
 "quantity":65,"settlePrice":100.0,"pnl":-645.75,"settledAt":"2026-11-10T15:30:00.000+05:30","version":77}}
{"type":"alert","seq":108,"asOf":...,"data":{"alertId":"A3","symbol":"RELIANCE","cond":"above","level":1500.0,"status":"triggered",
 "triggeredAt":"2026-11-06T11:40:02.200+05:30","triggerLtp":1500.05,"version":51}}
{"type":"pong","ts":1762412400000,"serverTime":1762412400012}
{"type":"error","id":3,"code":"too_many_chains","message":"Max 2 chain subscriptions per connection"}
```
- `strikes` in the chain ack = `[first, last, step]` (41 strikes). Snapshot rows carry every field; delta rows carry only changed
  fields; `atm` only when it moved; `spot` when it changed.
- **asOf rule (TR-2):** a `ticks` frame confirms the quotes in its `data`; a `chain` frame confirms **every cell in the
  subscribed range** of that chain; `ka` confirms the listed quote ids and chain ids. `ex` = subscribed items in scope that are
  **not** confirmed (frozen), with their last confirmed `asOf`.
- **ka:** every 1 s, lists quote ids and chain ids whose `lastConfirmedAt` is older than 250 ms and that are not frozen; worst
  healthy age ≈ 1.25 s (TR-3, FR-95). Sent only when the lists are non-empty.
- **Freeze (FR-121):** `frozenUntil[id]`. A frozen quote id is left out of `ticks` and `ka` and listed in `ex`; a frozen contract
  id is left out of chain deltas and listed in the chain frame's `ex`; freezing an underlying (e.g. `NIFTY`) freezes its quote
  **and** every chain on it (no chain frames, not in `ka`). The engine keeps trading; the first frame after the freeze carries
  the current values (diff against `lastSent`).
- **Resync (TR-9):** on `resync` the server sends, in order, one `ticks` frame with `"kind":"snapshot"` covering all subscribed
  quotes, one `chain` snapshot per chain sub (full range), then `{"type":"ack","id":7,"op":"resync","seq":<last seq>}`.
- **Account routing:** `AccountEvent`s and `alert`s go only to sessions with `ordersSub`/`alertsSub` (fixes v1 broadcast).
  `position`, `funds`, `settlement` ride the `orders` channel.
- **Errors:** `invalid_message`, `unknown_op`, `unknown_channel`, `invalid_mode`, `unknown_symbol`, `unknown_chain`,
  `too_many_subscriptions` (> 100), `too_many_chains` (> 2), `invalid_range`. Errors never change state.

---

## 5. REST (`rest_api.dart`, prefix `/api/v1`, `Authorization: Bearer demo-token`)

| Method · path | Request | Response |
|---|---|---|
| `GET /instruments` | `?kind=equity,index` (default) or `?kind=option&underlying=NIFTY` | `[Instrument]` with `kind, lotSize, tickSize, bandLow, bandHigh, strikeStep?, underlying?, expiry?, strike?, right?` |
| `GET /instruments/{id}` | — | `Instrument` or 404 `unknown_symbol` (ticket "Contract data unavailable") |
| `GET /quotes` | `?symbols=a,b&mode=quote|full` | `{"asOf":…,"quotes":[quote json]}` (options allowed) |
| `GET /expiries` | `?underlying=NIFTY` | `[{"expiry":"2026-11-10","expiryAt":ms,"kind":"weekly","isToday":false}]` |
| `GET /chain` | `?underlying=NIFTY&expiry=2026-11-10` | ack fields + snapshot body (same row JSON as §4.2) |
| `GET /orders` | `?key=<clientKey>` optional | `[Order]` newest first, or `[Order]` of length ≤ 1 for `key` |
| `GET /orders/{id}` | — | `Order` or 404 |
| `POST /orders` | header `Idempotency-Key`; `{"symbol","side","type","product","quantity"?,"lots"?,"limitPrice"?,"triggerPrice"?}` | 201 `Order`; 200 `Order` on key replay; 4xx `{"code","message"}` |
| `DELETE /orders/{id}` | — | `Order` (cancelled) or 409 `not_open` |
| `GET /positions` · `GET /holdings` · `GET /funds` | — | `[Position]` · `[Holding]` · `Funds` (each with `version`) |
| `GET /alerts` · `POST /alerts` · `DELETE /alerts/{id}` | `{"symbol","cond","level"}` | `[PriceAlert]` · 201 `PriceAlert` · `PriceAlert` |
| `GET /clock` | — | clock JSON (same as `clock` frame body) |
`OrderRejection` → 422 (validation), 404 (unknown), 409 (state); body `{"code","message"}`; v1 400 `invalid_body` kept.

---

## 6. Debug hooks (`debug_api.dart`, mounted only with `--debug`; FR-120…124)

| Route | Body / query | Effect |
|---|---|---|
| `POST /debug/clock` (FR-123) | `{"time":"2026-11-10T15:19:50+05:30"}` | forward only: `clock.jumpTo`, `scheduler.tick()`, `clock` frame; returns clock JSON. Backward → 409 `backward_jump_requires_reset` |
| `POST /debug/reset` (FR-112) | `{"time"?: iso}` | broker + alerts reset, funds ₹10,00,000, optional `jumpTo`, `scheduler.resetTo`, universe rebuilt, `clock` frame |
| `POST /debug/freeze` (FR-121) | `?symbol=X&seconds=N`; no symbol = v1 socket-wide freeze | per-id freeze (§4.2) |
| `POST /debug/faults` (FR-122) | `{"path":"/api/v1/orders","method":"POST","delayMs":0,"status":null,"dropAckAfterStore":false,"count":1}` | queue a `FaultPlan`; `DELETE /debug/faults` clears |
| `GET /debug/subscriptions` (FR-124) | — | `{"sessions":[{"id":"S1","quotes":12,"chains":1,"chainStrikes":21,"orders":true,"alerts":true}],"totals":{"sessions":1,"quotes":12,"chains":1},"activeAiAnswers":0}` |
| v1 `POST /debug/drop-connections`, `/debug/skip-seq` | — | unchanged |
`faultInjection(FaultInjector f)` shelf middleware (outside auth): for a request matching `path` prefix + `method`, decrement
`count`; `delayMs` → `await clock.delay(...)` before the handler; `status` → return that status with `{"code":"fault_injected"}`
without calling the handler; `dropAckAfterStore` → call the handler (order stored, events sent), then
`await clock.delay(delayMs or 20 s)` and return 504 `ack_dropped` (the client has timed out by then). `activeAiAnswers` is read
from a counter dev-ai's `ai_api` increments/decrements.

---

## 7. Client design

### 7.1 `core/market_time/`
```dart
abstract interface class Clock { DateTime now(); }                       // §10.2 — SystemClock, FakeClock
class SystemClock implements Clock { const SystemClock(); DateTime now() => DateTime.now(); }
class FakeClock implements Clock { FakeClock(DateTime start); void advance(Duration d); void set(DateTime t); }
final clockProvider = Provider<Clock>((ref) => const SystemClock());     // §10.2
class ServerClock { ServerClock(Clock device); DateTime now(); Duration get offset;                       // §10.2
  void onWelcome(int serverTimeMs, DateTime receivedAt);
  void onPong(int sentTsMs, int serverTimeMs, DateTime receivedAt); bool get synced; }
```
- `onWelcome`: `offset = serverTime − receivedAt`; `synced = true`; clears samples. `onPong`: `rtt = receivedAt − sentTs`;
  sample `offset = serverTime + rtt/2 − receivedAt`; keep last 5 `(rtt, offset)`; `offset` = the sample with the lowest rtt.
  Negative rtt (device clock stepped) → sample ignored. `now() = device.now() + offset`. Offset 0 until welcome; nothing is
  live before welcome because `socketLive` is false (TR-5).
```dart
enum MarketPhase { preOpen, open, closed }                               // §10.2
class MarketClockState { MarketPhase phase; int marketOffsetMs; String mode; String tradingDay; DateTime? nextPhaseAt;  // §10.2
  DateTime marketNow(DateTime serverNow) => serverNow.add(Duration(milliseconds: marketOffsetMs));
  bool overridden; factory MarketClockState.fromJson(Map<String, Object?> j); }   // + ==, copyWith
final marketClockProvider = StreamProvider<MarketClockState>(...);       // §10.2: ClockRepository.watch()
enum Freshness { live, stale, closed }                                   // §10.2
const kStaleAfter = Duration(seconds: 5);                                // §10.2
Freshness freshnessOf({required DateTime? asOf, required bool fromCache, required DateTime serverNow,
  required bool socketLive, required MarketPhase phase});                // §10.2
final freshnessTickProvider = StreamProvider.autoDispose<DateTime>(...); // §10.2: serverClock.now() every 250 ms
enum NetworkStatus { live, reconnecting, offline }                       // §10.2
final networkStatusProvider = StreamProvider<NetworkStatus>(...);       // §10.2
```
`freshnessOf` (PRD §3.1, exact; first match wins): `!socketLive` → stale · `fromCache` → stale · `phase != open` → closed ·
`asOf == null` → stale · `serverNow − asOf > kStaleAfter` → stale (5.000 s is live) · else live. Pure, synchronous, no allocation.
`ClockRepository`: `GET /clock` once, then `ClockMessage`s and `WelcomeMessage.clock`; `watch()` emits on change.
`NetworkStatusMonitor`: `live` when socket status is `SocketConnected`; otherwise after each failed connect attempt runs
`ApiClient.getHealth()` (3 s timeout, at most every 5 s): success or not yet probed → `reconnecting`; `SocketException`/timeout
→ `offline`. `SocketPaused` (background) → `reconnecting`.

### 7.2 `core/network/socket_messages.dart` (hand-written sealed family, `fromJson` with `switch`)
```dart
sealed class SocketMessage { int? get seq; }
final class WelcomeMessage   { String sessionId; int serverTime; int flushMs, keepAliveMs; MarketClockState clock; }
final class TicksMessage     { int seq; DateTime asOf; bool snapshot; List<Map<String, Object?>> data; Map<String, DateTime> ex; }
final class ChainMessage     { int seq; String chainId; ChainFrameKind kind; DateTime asOf; double? spot; int? atm;
                               ChainStatus? status; bool partial; List<Map<String, Object?>> rows; Map<String, DateTime> ex; String? nextExpiry; }
final class KeepAliveMessage { int seq; DateTime asOf; List<String> quotes; List<String> chains; }
final class ClockMessage     { int seq; MarketClockState clock; }
final class OrderMessage     { int seq; Map<String, Object?> data; }      // parsed by OrderRepository (version, clientKey)
final class PositionMessage, FundsMessage, SettlementMessage, AlertMessage { int seq; Map<String, Object?> data; }
final class AckMessage, ErrorMessage, PongMessage { /* no seq */ }
final class UnknownMessage   { Map<String, Object?> raw; }               // ignored, logged in Socket Lab
```

### 7.3 `MarketSocket` (changed; v1 backoff, generation guard, heartbeat, pause/resume kept)
```dart
MarketSocket(Uri url, {required Clock clock, required ServerClock serverClock, SocketConfig config, WebSocketChannel Function(Uri)? connect});
SocketSubscription subscribeQuotes(Iterable<String> ids, FeedMode mode, {int throttleMs = 250});   // §10.2
ChainSubscription subscribeChain(ChainRequest req);       // §10.2: updateRange(int from, int to), cancel()
AccountSubscription subscribeAccount({bool orders = true, bool alerts = true});                     // §10.2
Stream<SocketMessage> get messages;  DateTime? get lastFrameAt;                                     // §10.2
Stream<void> get resyncNeeded;       // v1 name kept: fires once per detected gap, after `resync` was sent
SocketStatus get status; Stream<SocketStatus> get statusChanges; Stream<SocketFrame> get frames;   // v1
```
- **Holders (TR-11):** `Map<String, List<_QuoteHold>>`; effective per id = max mode, min throttleMs. `_chainHolds` per chainId:
  effective range = union (min from, max to) clamped by the server. `_accountHolds` counts per channel.
- **Sync:** after any holder change, compute effective vs `_sent`; group changed ids by `(mode, throttleMs)` into `subscribe`
  ops; ids whose holder count reached 0 start a **300 ms linger** `Timer`; a new holder inside the linger cancels it (nothing
  sent); on expiry → `unsubscribe`. A holder leaving that raises the effective throttle (min) or lowers the mode re-sends
  `subscribe` for that id. Effective quote ids > 100 → the newest holder's extra ids are not sent and `CrashReporter.log
  ('quote_cap')`. On (re)connect every effective sub is sent once (NFR-11).
- **Frames:** `_onFrame` decodes once, `lastFrameAt = clock.now()`, `PerfMarks.mark('frame_received', seq: seq)` when
  `kPerfProbe`; `welcome` → `serverClock.onWelcome`, `pong` → `serverClock.onPong`; seq check: `seq != last + 1` → send
  `{"op":"resync"}` once (until its ack), fire `resyncNeeded`; then add the message to `messages`.
- `staleAfter` 12 s stays the half-open detector only (FR-90 banner uses `lastFrameAt` age > 5 s, owned by the screen layer).

### 7.4 Domain models (equality per ADR-0003)
```dart
class Quote { String id; double ltp, change, changePct, prevClose; DateTime asOf; int seq; bool fromCache;   // §10.2
  double? open, high, low, bid, ask; int? volume, lastQty; DateTime? lastTradeTime; bool iep; Depth? depth;
  Quote mergeJson(Map<String, Object?> j, {required DateTime asOf, required int seq}); Map<String, Object?> toJson(); }
  // == / hashCode exclude asOf and seq (and fromCache is included: cache → live flips rebuild once)
class ChainRequest { String underlying; String expiry; int fromStrike; int toStrike; }                         // §10.2
class OptionCell { String contractId; double ltp, change; int oi, oiChange; double? iv, delta; }               // §10.2, no asOf
class ChainRow { int strike; OptionCell? ce; OptionCell? pe; }                                                 // §10.2
enum ChainStatus { open, expired }
class ChainView { String chainId; int seq; DateTime asOf; double spot; int atm; ChainStatus status;            // §10.2
  List<int> strikes; Map<int, ChainRow> rows; Map<String, DateTime> exAsOf; DateTime asOfFor(String contractId); }
class Expiry { String code; DateTime expiryAt; ExpiryKind kind; bool isToday; }
class Instrument { String id; String name; InstrumentKind kind; int lotSize; double tickSize; double? bandLow, bandHigh;
  int? strikeStep; String? underlying; String? expiry; int? strike; OptionRight? right; }
class Order { String id; String? clientKey; int version; String symbol; ProductType product; OrderSide side; OrderType type;
  int quantity; int? lots; double? limitPrice, triggerPrice, averagePrice; OrderStatus status; String? reason, message;
  DateTime createdAt, updatedAt; }
class OrderRequest { String symbol; OrderSide side; OrderType type; ProductType product; int? quantity; int? lots;
  double? limitPrice; double? triggerPrice; Map<String, Object?> toJson(); }
sealed class PlaceOutcome {}  // PlaceAcked(Order) · PlaceRejected(String code, String message) · PlaceTimedOut()  §10.2
class Position { String symbol; ProductType product; int quantity; int? lots; double averagePrice, realizedPnl, dayRealizedPnl; int version;
  factory Position.fromJson(Map<String, Object?> j); Map<String, Object?> toJson(); }        // v1.1 (R3): wire JSON = snapshot JSON
class Holding { String symbol; int quantity; double averagePrice; int version;
  factory Holding.fromJson(Map<String, Object?> j); Map<String, Object?> toJson(); }         // v1.1 (R3)
class Funds { double available; int version; factory Funds.fromJson(...); Map<String, Object?> toJson(); }
class PortfolioBook { List<Position> positions; List<Holding> holdings; Funds? funds; }    // §10.2 v1.1; unmodifiable lists, value ==
class PriceAlert { String alertId; String symbol; AlertCondition cond; double level; AlertStatus status;
  DateTime createdAt; DateTime? triggeredAt; double? triggerLtp; int version; }
class Settlement { String settlementId; String symbol; ProductType product; int quantity; double settlePrice, pnl; DateTime settledAt; }
```
`ChainView.asOfFor(id) = exAsOf[id] ?? asOf`. `ChainView ==` compares chainId, seq, status, spot, atm and row **identity**
(rows are rebuilt only when changed), so controllers can `select` rows by strike.

### 7.5 Repositories
**`MarketRepository`** (changed)
```dart
Stream<List<Quote>> watchQuotes(List<String> ids, FeedMode mode, {int throttleMs = 250});   // §10.2
Future<Result<List<Quote>>> getQuotes(List<String> ids, {bool full = false});
Future<Result<List<Instrument>>> getInstruments({InstrumentKind? kind, String? underlying});
Future<Result<Instrument>> getInstrument(String id);          // §10.2 v1.1 (404 → "Contract data unavailable")
List<String> get watchlistIds;  void setWatchlist(List<String> ids);   // §10.2 v1.1 (R3); setWatchlist calls SnapshotStore.markStructuralDirty()
List<Quote> latestQuotes(Iterable<String> ids);  void seedFromCache(List<Quote> cached);   // §10.2 v1.1; seed sets fromCache: true
Quote? latest(String id);
final liveQuoteProvider = StreamProvider.autoDispose.family<Quote, ({String id, int throttleMs})>(...);   // §10.2
```
- `_latest: Map<String, Quote>`. `TicksMessage` → for each entry `mergeJson(asOf: msg.asOf, seq: msg.seq)`, `fromCache = false`;
  `ex` ids → keep the quote, set `asOf = ex[id]`. `KeepAliveMessage` → for listed ids, copy with new `asOf` (equal by `==`).
  Emit to each watcher the list of its ids touched by the message (ticks **and** ka), so freshness sees the new `asOf`
  while `select` on price fields does not rebuild.
- REST `getQuotes` merge guard: apply only when `json.asOf > latest.asOf` (one server wall clock, TR-2); never by `t`.
- Watchlist ids (R3): default `[NIFTY, RELIANCE, HDFCBANK, …]` (FR-3) until `seedFromCache`/`setWatchlist`; `setWatchlist`
  stores an unmodifiable copy, calls `ref.read(snapshotStoreProvider).markStructuralDirty()` (injected `SnapshotStore`), and
  emits on `watchWatchlistIds()` for the watchlist controller. `latestQuotes(ids)` = `_latest` values in `ids` order, missing ids
  skipped; read-only, used by dev-perf's `SnapshotScheduler`.
- `watchQuotes`: on listen `socket.subscribeQuotes`; replays `_latest` values at once (their old `asOf` ages normally, HLD §8.5);
  on cancel `sub.cancel()` (linger in the socket).

**`ChainRepository`** (new)
```dart
abstract interface class ChainFeed { Stream<ChainView> get views; void setVisibleRange(int fromStrike, int toStrike); } // §10.2
ChainFeed watchChain(ChainRequest req);                     // §10.2 — cancel = cancel the views subscription
Future<Result<List<Expiry>>> expiries(String underlying);   // §10.2
Future<Result<ChainView>> getChain(String underlying, String expiry);   // REST, used for first paint before the socket
```
`ChainFolder` (pure, unit-tested): `ChainView? apply(ChainView? v, SocketMessage m, {required bool awaitingSnapshot})`:
- `ChainMessage(snapshot)`: build rows for the snapshot strikes (partial → merge into `v.rows`), clear those ids from `exAsOf`,
  `seq = m.seq`, `asOf = m.asOf`; clears `awaitingSnapshot`.
- `ChainMessage(delta)`: ignored while `awaitingSnapshot` or `m.seq <= v.seq`; for each row, `copyWith` only the changed cell
  fields → new `OptionCell`/`ChainRow` only for those strikes; unchanged rows keep identity; `exAsOf` = `m.ex` merged.
  `iv`/`delta` absent from a delta keep their last value, so `OptionCell.iv`/`delta` are always populated after the snapshot (D6).
- `ChainMessage(status)`: `status = expired` (dev-trading moves the picker, FR-29c).
- `KeepAliveMessage` listing the chainId → `asOf` only.
- Range shrink (`setVisibleRange` → `ChainSubscription.updateRange`): cells leaving the range keep their values and are put in
  `exAsOf` with the current `asOf`, so they age to stale instead of claiming freshness; re-entering strikes get a partial snapshot.
- `resyncNeeded` → `awaitingSnapshot = true` until the resync snapshot arrives.
`setVisibleRange(from, to)` is debounced **250 ms** in the feed, then `updateRange(from − 5·step, to + 5·step)` (TR-7).

**`OrderRepository`** (new; v1 order code moves here)
```dart
Future<PlaceOutcome> place(OrderRequest req, {required String idempotencyKey, Duration timeout});   // §10.2
Future<Result<Order?>> getOrder({String? id, String? clientKey});                                   // §10.2
Stream<Order> get updates;  Stream<void> get resyncCompleted;                                       // §10.2
Future<Result<List<Order>>> getOrders();  Future<Result<Order>> cancel(String id);
```
- `place` = **one** POST attempt with the `Idempotency-Key` header and `timeout` (default 5 s). 201/200 → merge → `PlaceAcked`;
  4xx with `code` → `PlaceRejected`; timeout / `NetworkFailure` / 5xx → `PlaceTimedOut`. Retries with the same key (≤ 2) are the
  ticket state machine's (dev-trading `06-lld/trading.md`), so each retry is visible as `CheckingStatus`.
- `_orders: Map<String, Order>` merged by **version** (higher wins) from REST acks, `OrderMessage`s and reloads; `updates`
  emits only when a version increases (TR-10). `clientKey` lets the ticket resolve Placing from a frame before the ack.
- `getOrder(clientKey:)` → `GET /orders?key=`; `getOrder(id:)` → `GET /orders/{id}`.
- `resyncCompleted`: forwarded from `ResyncCoordinator`, which on `resyncNeeded` (and after every reconnect) runs registered
  reloaders in parallel — orders, positions, holdings, funds, alerts — merges each by version, then emits once.

**`PortfolioRepository`** (changed): `Stream<List<Position>> watchPositions()`, `Stream<List<Holding>> watchHoldings()`,
`Stream<Funds> watchFunds()`, `Stream<Settlement> get settlements`, `getPositions()`, `getHoldings()`, `getFunds()` (§10.2 v1.1);
merged by version per key (`"$symbol|$product"` for positions, `symbol` for holdings).
`PortfolioBook? get current` (§10.2 v1.1, R3): read-only latest merged book (`null` until the first REST load or a cache seed),
for dev-perf's `SnapshotScheduler`; `void seedFromCache(PortfolioBook book)` marks rows display-only until `GET /positions`
returns (perf.md). A position or holding added/removed (not a price change) calls `markStructuralDirty()`.

**`AlertsRepository`** (new)
```dart
Future<Result<List<PriceAlert>>> list();  Future<Result<PriceAlert>> create(String symbol, AlertCondition cond, double level);
Future<Result<PriceAlert>> delete(String alertId);  Stream<List<PriceAlert>> watchAll();
Stream<PriceAlert> get triggered;   // §10.2 — deduped by alertId against LocalPrefs.seenAlertIds
```
`triggered`: from `AlertMessage` and from REST reloads (status triggered); if `alertId ∈ LocalPrefs.data.seenAlertIds` → drop,
else `await localPrefs.update(add id)` then emit (FR-55: live + resync = 1 banner).

**Providers** (manual, in each feature's `data/providers.dart`): `marketSocketProvider` (v1, now with clocks),
`resyncCoordinatorProvider`, `marketRepositoryProvider`, `chainRepositoryProvider`, `orderRepositoryProvider`,
`portfolioRepositoryProvider`, `alertsRepositoryProvider`, `clockRepositoryProvider` — all `Provider` with `ref.onDispose`.

### 7.6 ApiClient, DebugClient (v1.1: R2, R4, R5; debug screens moved to perf.md in v1.2)
```dart
// core/network/api_client.dart (owner dev-realtime)
Future<http.StreamedResponse> ApiClient.send(http.BaseRequest req);      // §10.2 v1.1: adds Authorization: Bearer <token>, base URL already resolved by caller
Future<Result<void>> ApiClient.getHealth({Duration timeout = const Duration(seconds: 3)});
// dev-ai: extension ApiClientLines on ApiClient { Stream<Map<String, Object?>> postLines(String path, Object body); } in api_client_lines.dart
// core/network/debug_client.dart
abstract interface class DebugClient { Future<Result<MarketClockState>> setClock(DateTime marketTime);  // §10.2 v1.1; 409 backward_jump_requires_reset
  Future<Result<void>> reset({DateTime? marketTime}); }
class HttpDebugClient implements DebugClient { HttpDebugClient(ApiClient api); }
final debugClientProvider = Provider<DebugClient>((ref) => HttpDebugClient(ref.watch(apiClientProvider)));
```
- `send` is the one place that adds the auth header; v1 `get/post/delete` helpers call it. It never logs headers or bodies.
- `setClock` → `POST /debug/clock {"time": iso}`; 409 maps to `Err(ConflictFailure('backward_jump_requires_reset'))`.
  `reset` → `POST /debug/reset {"time"?}`. Callers of `reset` (More › Reset, owned by dev-perf; debug clock screen) also run
  the local wipe (FR-112, perf.md).
- **Debug clock screen and Socket Lab UI** (FR-110, FR-111, story S-41) moved to `perf.md` §7.1 in v1.2. This file keeps only the APIs they call: `DebugClient` (above), `MarketSocket.frames` (§7.3) and the `/debug/*` endpoints (§6).

---

## 8. Error handling

| Where | Failure | Handling |
|---|---|---|
| Gateway | bad JSON, unknown op/channel, caps | `error` frame with `id`; state unchanged |
| Gateway | send on closed sink | `_closed` guard (v1); session cleanup cancels timers and books |
| Broker / alerts | validation | `OrderRejection` / `AlertRejection` → 4xx `{code, message}` |
| Scheduler | handler throws | caught per handler, logged with event key; remaining handlers still run; key stays processed |
| Pricer | NaN/∞ (T→0, iv→0) | `bsPrice` intrinsic branch; result clamped ≥ 0.05; NaN → keep previous ltp and log |
| Debug | backward clock, bad time | 409 `backward_jump_requires_reset` / 400 `invalid_time` |
| Socket client | decode error | frame dropped, logged to Socket Lab; no seq update |
| Socket client | `error` frame | `CrashReporter.log('socket_error', {code})`; caps → log; no retry loop |
| Repositories | REST failure | `Result.err(Failure)`; resync reloader failure leaves state and retries on the next reconnect |
| ChainFolder | delta for unknown strike | ignored and counted (test asserts 0 in normal runs) |

---

## 9. Tests (all automated; IDs traced to FR/TR/NFR)

### 9.1 `packages/option_math` (unit)
| Test | Trace |
|---|---|
| `bsPrice` S=100 K=100 T=1 r=0.05 iv=0.2: CE 10.4506, PE 5.5735 (±1e-4) | TR-18, FR-27 |
| Put-call parity `C − P = S − K·e^(−rT)` over a grid | TR-18 |
| `years <= 0` / `iv <= 0` → intrinsic | TR-26 |
| Greeks vs finite differences (Δ, Γ, Θ per day, Vega per point) within 1e-3 | FR-27 |
| `yearsToExpiry` uses the args only (market time), clamps at 0 | ADR-0002 |

### 9.2 Server unit (`market_server/test/`)
| File | Cases | Trace |
|---|---|---|
| `market_clock_test` | demo start 10:00 IST on weekday / weekend / holiday; `jumpTo` moves market only, wall unchanged; `FakeMarketClock.delay` | FR-116, FR-120, TR-4 |
| `market_calendar_test` | phase edges 08:59:59.999 / 09:00 / 09:14:59.999 / 09:15 / 15:29:59.999 / 15:30; weekend, holiday; weekly + monthly expiries; Tuesday holiday → Monday | §3.2, FR-24, FR-37 |
| `clock_scheduler_test` | 15:19:59→15:20:00 fires squareOff once; jump over 2 days replays dayRoll/open/close in order; replay of a processed key is skipped; > 10 days fast-forward; settle only on expiry day | FR-44, FR-46, FR-49, FR-111 |
| `option_instruments_test` | 41 strikes centred on prevClose; id format; strike set unchanged when spot moves 3 strikes; pinned contracts survive rebuild; next far expiry listed at day roll | FR-20, FR-29c, TR-25 |
| `option_pricer_test` | price ≥ 0.05, tick multiple; smile skew sign; T floor near 15:29:59; options frozen in pre-open; 500 contracts reprice < 1 ms (benchmark) | TR-26, §3.2 |
| `chain_book_test` | delta contains only changed fields; greeks ≤ 1 Hz; frozen id → `ex`; range growth returns new strikes only; `null` when nothing changed | FR-29a, TR-2 |
| `broker_test` | every validation code in order; band 80.00–120.00 and 120.05 rejected; tick 101.03 rejected; option band 0.05–3×; lots × 50 fixture; (symbol, product) not netted; CNC sell > held; funds debit/credit; pre-open limit queued then filled at 09:15; idempotent replay; `version` monotonic; MIS square-off leaves CNC/NRML | FR-32…39a, FR-41, FR-44, FR-46, NFR-9 |
| `expiry_service_test` | FR-49 example ₹6,500; replayed jump settles once; open orders on expiring contracts cancelled; chain status expired | FR-49, FR-29c |
| `alerts_engine_test` | crossing above/below; one-shot; `condition_already_met`; no trigger while Closed | FR-50, FR-51 |
| `market_reads_test` | PCR and max-pain on a fixed OI fixture; topMovers order; facade has no mutators | dev-ai §5 |

### 9.3 Server end-to-end (`server_test.dart`, in-process `MarketServer` + `FakeMarketClock`, real WebSocket)
| Case | Trace |
|---|---|
| `welcome` has `serverTime` + `clock`; `pong` has `serverTime` | FR-93, FR-94 |
| Every data frame has `seq` +1 and `asOf`; `ack`/`pong`/`error` have no seq | TR-1, TR-2 |
| Unchanged subscribed quote: `asOf` confirmations ≤ 2 s apart over 10 s (ka) | FR-95, FR-91 |
| Freeze RELIANCE 6 s: absent from ticks and ka, listed in `ex`; TCS keeps ticking | FR-121, FR-5 |
| Chain subscribe → ack + snapshot of the range; deltas changed-only; 3rd chain → `too_many_chains`; 101st quote → error | FR-29a, TR-7 |
| `/debug/subscriptions` shows 1 chain sub and 0 extra quote subs with the chain open; 0 after close | FR-124, NFR-14 |
| `skip-seq` → client `resync` → ticks snapshot + chain snapshots + resync ack in order | FR-84, TR-9 |
| Orders frames only on the session subscribed to `orders`; `clientKey` + `version` present | ADR-0001, TR-10 |
| `faults dropAckAfterStore` on POST /orders → 1 order stored, `GET /orders?key=` finds it, retry with key → same order | FR-122, FR-31 |
| `/debug/clock` 15:19:50 → +10 s → MIS squared off (order frames), `clock` frame phase stays open; 15:30 → settlement frame | FR-123, FR-44, FR-49 |
| Backward `/debug/clock` → 409; `/debug/reset` with time works | §6 |
| Clock jump does not change `asOf` progression (wall) | TR-4 |
| Server restarted on the same port: new welcome, subs restored once (via client test 9.4) | NFR-11 |

### 9.4 Client (`stock_pulse/test/`, unit + integration with `TestServer`)
| File | Cases | Trace |
|---|---|---|
| `server_clock_test` | welcome offset; pong lowest-RTT of 5; device clock +30 s → same `now()` | FR-94, TR-5 |
| `freshness_test` | age 4.9 / 5.0 / 5.1 s; socket down; fromCache; preOpen/closed → closed; asOf null; +30 s skew | NFR-7, §3.1 |
| `market_socket_test` (extend v1) | mode max / throttle min; holder leaves → re-send; linger 300 ms (fake_async) with re-listen inside → 0 ops; cap 100; resubscribe once after reconnect; gap → one `resync` op | TR-11, FR-84, FR-63 |
| `socket_messages_test` | every frame in §4.2 parses; unknown type → `UnknownMessage` | TR-1 |
| `chain_folder_test` | snapshot → 41 rows; delta changes only touched row identities; ka changes `asOf` only (rows identical); stale delta (seq ≤) ignored; delta while awaiting snapshot ignored; range shrink → `exAsOf`; status expired | ADR-0003, FR-23, FR-29c, NFR-5 |
| `market_repository_test` | ka emits a quote `==` the previous but with new `asOf`; REST older `asOf` not applied; `ex` keeps value with old `asOf`; seed → fromCache until first live frame | FR-81, FR-84, FR-91 |
| `order_repository_test` | Acked / Rejected / TimedOut mapping; version merge (frame before ack); `getOrder(clientKey)`; resyncCompleted after reloads | FR-31, FR-31a, TR-10 |
| `alerts_repository_test` | same alertId live + resync → 1 emit; seen-set persisted | FR-55, FR-54 |
| `network_status_test` | connected → live; reconnecting with health ok; health fails → offline | FR-31a |
| `api_client_test` (v1.1) | `send` adds the auth header once; helpers go through `send`; no header in logs | R2, TRD §4 |
| `market_repository_watchlist_test` (v1.1) | `setWatchlist` stores a copy and calls `markStructuralDirty` once (fake `SnapshotStore`); `latestQuotes` order and missing ids | R3, FR-80 |
| `portfolio_repository_test` (v1.1) | `current` null → book after REST; `Position`/`Holding` JSON round-trip; structural change marks dirty, price change does not | R3, FR-80, FR-41 |
| `debug_client_test` (v1.1) | `setClock` 200 → state; 409 → `ConflictFailure`; `reset` body with/without time | R4, FR-123, FR-112 |
| integration `resync_test` | skip-seq: provider never holds an older value; fill count and alert count = 1 | FR-84, NFR-10 |
| integration `restart_test` | 20 loops: kill + re-serve → live ≤ 10 s, positions equal server | NFR-11 |
| integration `freeze_test` | freeze one symbol → only it stale at 5.1 s (FakeClock) | FR-5, FR-91, NFR-8 (data side) |

---

## 10. Order of work (HLD §10.3 step 2, then 3–5)
1. Stubs of every §10.2 type I own + fakes (`FakeClock`, `FakeMarketClock`, fake `MarketSocket`), `pricing.dart` + tests.
2. M-A: `ist`, `market_clock`, `market_calendar`, `clock_scheduler`; protocol v2 (welcome/pong `serverTime`, frame `asOf`, `ka`,
   channels, `resync`); debug hooks FR-121…124; `ServerClock`, `freshnessOf`, providers; `MarketRepository` changes.
3. M-B: option universe, pricer, chain book + channel, `ChainRepository`; broker F&O rules, expiry service, `OrderRepository`.
4. M-C: holdings/funds REST + frames, alerts engine + `AlertsRepository`.
5. M-D: `MarketReads` for dev-ai.

---

## Build notes (S-1 deviations, dev-realtime)
- `InstrumentKind.index` is not legal Dart (clashes with `Enum.index`): the value is `InstrumentKind.marketIndex`, wire name `"index"` (`fromWire` / `.wire`), server and client.
- `MarketSocket.messages` stays the v1 `Stream<Map>` until S-10a (only realtime repositories and the v1 Socket Lab read it); the typed `SocketMessage` family exists in `socket_messages.dart`. `clock` / `serverClock` are optional constructor args until S-10a.
- `Quote` / `Instrument` keep v1 field names (`symbol`, `changePercent`) with §10.2 getters `id`, `changePct`; renamed in S-10a / S-6.
- `HttpDebugClient` returns `ServerFailure(409, 'backward_jump_requires_reset')` until `ConflictFailure` is added to `core/error` (S-8).
- v1 `portfolio/domain/order.dart` re-exports the v2 `OrderSide`; `Position` moved to `portfolio/domain/position.dart` (re-exported). v1 `OrderType` / `OrderStatus` stay until S-25.
