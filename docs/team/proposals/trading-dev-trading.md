# Proposal: trading screens (dev-trading, propose round)

Inputs: PRD v1.1, UX spec v1.3, design system v1.3, v1 code (`app.dart`, `core/`, `market/presentation`, `portfolio/`).
Constraints honoured: manual Riverpod 3 providers, hand-written immutable classes + JSON, no codegen, one controller per screen.

## 1. Scope
- **Option chain:** FR-20…FR-29c (FR-27 greeks sheet uses the shared `option_math`), FR-25, NFR-5, NFR-14 (chain sub range), NFR-16.
- **Order entry:** FR-26, FR-30…FR-39a, FR-92, FR-113 (risk notice gate), NFR-8, NFR-9, NFR-13.
- **Portfolio:** FR-40…FR-49 (UI side; FR-44/46/49 are server work, I render notices), FR-31a Pending rows.
- **Alerts:** FR-50…FR-55 (list, create, banner queue while a sheet is open).
- **Shell + platform:** 5-tab shell with lazy tabs FR-82 (FR-86 signal from dev-perf), FR-100…FR-102, FR-126 fake haptics, NFR-12 for my screens.

## 2. Folders, controllers, states, providers
```
lib/core/theme/      sp_colors.dart  sp_typography.dart  sp_tokens.dart (SpSpace, SpRadius, SpDensity)  app_theme.dart  theme_x.dart (context.sp)
lib/core/platform/   haptics.dart (Haptics interface, MethodChannelHaptics, NoopHaptics)  haptic_dedupe.dart
lib/core/widgets/    sp_price_cell, change_chip, stale_badge, pending_badge, segmented_choice, lot_stepper, sp_sheet, sp_snack
lib/app/             app_shell.dart (5 tabs, lazy)  order_outcome_listener.dart (evolves v1 OrderUpdateListener)
features/options/    domain: OptionContract, ChainCell, ChainStrike, Expiry · presentation: option_chain_screen, option_chain_controller, widgets/ (chain_row, chain_cell, oi_bar, strike_cell, back_to_atm_fab, expiry_chips, cell_action_sheet, greeks_sheet)
features/orders/     domain: OrderDraft, OrderRequest, ProductType, OrderType, OrderValidator (pure), ConfirmBlock · presentation: order_ticket_sheet, order_ticket_controller, risk_notice_screen
features/portfolio/  domain: Position (keyed symbol+product), Holding, Order(+pending) · presentation: portfolio_screen, portfolio_controller, widgets/
features/alerts/     domain: PriceAlert · presentation: alerts_screen, alerts_controller, alert_create_sheet, alert_create_controller, alert_banner_host
```
Data repositories (chain, orders, alerts, funds) come from dev-realtime; I only consume them (section 7).

| Screen | Provider (manual) | State (immutable, hand-written `==`/`copyWith`) |
|---|---|---|
| Option chain | `optionChainControllerProvider` `AsyncNotifierProvider.autoDispose` (kept alive by the tab) | `OptionChainState{underlying, expiries, expiry, strikes: List<int> (41, fixed), cells: Map<String, ChainCell>, spot, spotAsOf, atmStrike, oiMax, feedStale, columns: Set<ChainColumn>, phase}`; `ChainCell{contractId, ltp, change, oi, oiChange, iv?, delta?, asOf, isStale}` |
| Order ticket | `orderTicketControllerProvider` `NotifierProvider.autoDispose.family<…, OrderTicketArgs>` | `OrderTicketState{instrument (lot, tick, band, kind, expiry), side, product, type, lots/qty, priceText, triggerText, ltp, asOf, tradedStale, underlyingStale, phase, network, fundsAvailable, fieldErrors, dismissedNudges, submit: SubmitPhase, source}` + getters `units`, `orderValue`, `maxLoss`, `confirmBlock` |
| Portfolio | `portfolioControllerProvider` (evolves v1) | `PortfolioState{positions, holdings, orders, ltp: Map<String, LtpQuote>, funds, tab, fromCache, savedAt}` + summary getters per tab (FR-47) |
| Alerts list / create | `alertsControllerProvider`, `alertCreateControllerProvider.family<AlertCreateArgs>` | `AlertsState{active, triggered, ltp}` · `AlertCreateState{direction, priceText, ltp, error, saving}` |
| Risk notice | `riskNoticeAckProvider` (`AsyncNotifier<bool>`, local prefs) | bool; screen itself stateless |
| Haptics | `hapticsProvider` (`Provider<Haptics>`), `hapticsEnabledProvider` | — |

Rules: `ref.watch` only in `build`, `ref.read` in callbacks, `ref.mounted` after every await, no `BuildContext` in controllers (navigation and snacks via `ref.listen` in the widget on state transitions).

## 3. Option chain at 60 fps (NFR-5)
- **List:** one `ListView.builder` (`itemCount: 41`, `itemExtent: 48`, `addAutomaticKeepAlives: false`), header and column labels outside the list. Row key `ValueKey(strike)`; rows never re-index (FR-20).
- **What rebuilds on a tick:** the controller applies one `ChainDelta` per frame (deltas coalesced in a microtask buffer, flushed once) as a new `cells` map. Each `ChainCell` widget is a `ConsumerWidget` doing `ref.watch(provider.select((s) => s.value?.cells[id]))`; `ChainCell ==` compares fields, so only changed cells rebuild. `ChainRow` is a `StatelessWidget` with `RepaintBoundary`, and the strike cell selects only `(isAtm, isItmCall)` as a record, so an ATM move rebuilds just the rows whose flags flip (FR-23). Target: rebuilds per tick ≤ changed cells (build counter test).
- **OI bars:** `OiBar` selects a quantised width bucket `(oi / oiMax * 40).round()`; a new `oiMax` rebuilds only bars whose bucket changes. Painted with one `CustomPaint.drawRect`, no animation.
- **Stale:** controller re-evaluates the stale rule on a single 250 ms timer and on frames; it emits new state only when some `isStale` flag flips. No per-cell timers. Socket-level stale sets `feedStale` once.
- **ATM without auto-scroll:** the `ScrollController` lives in the screen `State`. Jump (no animation) to `atmIndex*48 - (viewport*0.55 - 24)` only on first layout and on expiry/underlying change (`ref.listen` on `(underlying, expiry)`), never on ATM change. "Back to ATM" visibility is a local `ValueNotifier<bool>` fed by a `ScrollNotification` listener, so only the FAB rebuilds.
- **Visible range:** the screen reports the visible strike range (debounced 250 ms) and the controller calls `updateRange(visible ± 5)` on the one chain sub (FR-29a, NFR-14). Hidden tab → stream paused, cells keep values and show stale until the first frame.
- **Deep link / AI target:** `ChainTarget` centres the target strike instead of ATM and selects the cell (2 dp outline, static).

## 4. Order flow state machine (FR-31, FR-31a, FR-38, FR-38a)
```
SubmitPhase (sealed): Idle → Placing(key, startedAt) → CheckingStatus(key, attempt) → Placed(order) | Rejected(code, msg) | Pending(key)
```
1. `confirm()` returns at once unless `submit is Idle` (one in flight; 2 taps 50 ms apart = 1 POST).
2. **Stale check at send time:** `confirm()` reads `serverClock.now()` and the latest quote, calls the pure `isStale(asOf, now, status, phase)` and the `OrderValidator`, then calls `repo.place(...)` in the same synchronous turn, with no `await` in between. Stale → state keeps inputs, `confirmBlock = staleSince(asOf)`, 0 POSTs (NFR-8, fake-clock widget test at 4.9/5.0/5.1 s).
3. Key: one random 128-bit key per draft attempt, reused across retries, reset only after `Rejected` plus an edit.
4. Placing; after 3 s with no answer the label switches to `CheckingStatus` (`Semantics(liveRegion)`). Timed-out POST retried with the **same key**, max 2 retries (1 s, 2 s). A socket `order` frame with matching `clientKey` resolves the state early.
5. Stale arriving after send changes nothing (FR-38a). Sheet is not dismissable and back is ignored while Placing/Checking (`PopScope(canPop: false)`, `enableDrag: false`).
6. Outcomes: `Placed` → widget closes the sheet, snack "Filled…"; `Rejected` → inline banner, sheet scrolls to it, inputs kept; retries exhausted → `Pending`: sheet closes, snack "Order status unknown. See Orders", portfolio gets a Pending row; **never** resubmit. Pending row action `Refresh status` = `GET /orders/{id}`, disabled only when `network is Offline`.
7. `ConfirmBlock` priority: placing > offline > closed > pre-open option > contract missing > traded stale > field error. Underlying stale is a nudge, not a block (E20). Reason line sits above Confirm.
8. Haptics never fire from the sheet: `OrderOutcomeListener` (app level) fires once per `(orderId, status)` via `HapticDedupe`, so a fill seen live and via resync gives 1 haptic. A rejection with no order id uses `(key, rejected)`.
9. Risk notice: ticket opener checks `riskNoticeAckProvider` first for F&O; "Not now" returns to the chain.

## 5. Theme plan
- `SpColors extends ThemeExtension<SpColors>`: all 03b §2 tokens (`surface1/2`, `textTertiary`, `up`, `down`, `warn`, `info`, `buy`, `sell`, tints as getters), `const dark`/`const light`, `copyWith`, `lerp` (`Color.lerp` per field), `directionOf(change)`.
- `SpTypography extends ThemeExtension`: `price`, `priceDense`, `change`, `strike`, `caption`, all with `FontFeature.tabularFigures()` and the bundled font.
- Spacing, radius, density stay **`abstract final class` consts** (`SpSpace`, `SpRadius`, `SpDensity`), not a ThemeExtension: they never vary by theme and consts are free (03b §8).
- `AppTheme.dark()/light()` build an explicit `ColorScheme` (no seed) plus component themes (segmented, sheet, snackbar, nav, inputs). `themeMode: ThemeMode.system` + Settings override. Access `context.sp`, `context.spText`.
- **Migration of v1 `MarketColors`:** (1) add theme; (2) replace `TickPrice` with `SpPriceCell` (1.5 s tint computed from tick time, no timer) and `QuoteTile` colours with `context.sp.directionOf`; (3) fix `ConnectionBadge` hues; (4) delete `market_colors.dart`; (5) CI grep: no `MarketColors` and no `Colors.` outside `core/theme`. Goldens in both themes at 1.0× and 2.0×.

## 6. Haptics platform channel (FR-100…102, FR-126)
- Dart: `MethodChannel('stockpulse/haptics')`, methods `success`, `rejection`, no args. `Haptics` interface; `MethodChannelHaptics` catches `MissingPluginException`/`PlatformException`, logs once, then becomes a no-op. On `kIsWeb` or macOS/Windows/Linux the provider returns `NoopHaptics`. Toggle off → no calls (FR-102).
- **Android (Kotlin, `MainActivity.configureFlutterEngine`):** API 30+ `window.decorView.performHapticFeedback(CONFIRM | REJECT)`; below 30 `Vibrator`/`VibrationEffect.createWaveform` (success: medium then light 80 ms apart; rejection: two heavy 120 ms apart), `VIBRATE` permission; returns `result.success(null)`, never throws to Dart.
- **iOS (Swift, `AppDelegate`):** `UINotificationFeedbackGenerator` `.success` / `.error`, `prepare()` on channel setup; silent if no Taptic hardware.
- Tests: `FakeHaptics` provider override (counts calls) for widget tests; one channel test with `TestDefaultBinaryMessengerBinding` mock handler.

## 7. Interfaces I need
- **dev-realtime:** `ChainRepository.watchChain(ChainRequest) → Stream<ChainUpdate>` (sealed `ChainSnapshot{seq, spot, strikes, cells}` / `ChainDelta{seq, cells}`, every cell with `asOf`) + `updateRange`; `serverClockProvider`; pure `isStale(...)`; `marketPhaseProvider`; `NetworkStatus` (Offline vs Reconnecting); `OrderRepository.place(req, key, timeout) → PlaceOutcome` (Acked / Rejected / TimedOut), `getOrder`, order frames echoing `clientKey`; `resyncCompleted` stream; alerts `watchTriggered()` with `alertId`, `triggeredAt`; instrument metadata (lot, tick, band, kind, expiry); funds.
- **dev-ai:** call `openOrderTicket(context, OrderTicketArgs(..., source: OrderSource.ai))`, `openChain(ChainTarget)`, `openAlertCreate(AlertCreateArgs)`; none can submit.
- **dev-perf:** `screenVisibleProvider(ScreenId)` (tab selected and not covered); snapshot cache read for portfolio (fromCache → stale style); `price_painted(seq)` mark hook; build-counter test helper; lazy tab contract (placeholder until first visit, `TickerMode` per tab).

## 8. Risks and rejected alternatives
| Risk | Mitigation |
|---|---|
| 03b says ATM row 52 dp; variable extent breaks `itemExtent` and shifts offsets when ATM moves (FR-23 ±0 px) | Keep all rows 48 dp, draw the ATM rules inside 48; ask design to accept |
| `oiMax` change rebuilds every bar | Quantised width bucket select |
| Map copy per delta (82 entries) | Cheap; coalesce per frame; measure on Pixel 6a |
| Family ticket state lost if sheet route rebuilds | Args are value-equal; provider kept by the sheet's watch |
| Double haptic (sheet + socket) | Haptics only from the dedupe listener |

Rejected: per-contract `StreamProvider.family` (82 subs, breaks FR-29a); `DataTable`/`Table` (no virtualisation); two synced CE/PE lists (scroll jitter); auto-scroll to ATM (FR-23); `animateTo` (UX says instant); a stale timer per cell; checking stale only when Confirm is tapped (gap before send, NFR-8); `HapticFeedback` alone (no success/error on Android; kept for `selectionClick`); third-party vibration plugin (channel is the JD point); freezed/riverpod_generator (NFR-18).

## 9. Critiques and answers (critique round)
**Answers given**
- **dev-ai (route args):** adopt dev-ai's names. `OrderTicketArgs{instrumentId, side, lots?, product?, limitPrice?, source}`, `AlertArgs{instrumentId, direction?, price?, source}`, `ChainArgs{underlying, expiry?, strike?, right?}`. Entry points `openOrderTicket(context, args)` (shows the F&O risk notice first if not acknowledged), `openChain(args)` (target strike centred and outlined, no auto-scroll after), `openAlertCreate(context, args)`. The ticket's "Payoff ›" opens the builder with `StrategyArgs{legs: [draft leg, premium = ticket LTP]}`.
- **dev-realtime:** accept `Freshness.of(asOf, phase, status, serverNow)` in place of my `isStale`; I send raw first/last visible strike and drop my 250 ms debounce (they debounce 150 ms, buffer 5); order/position frames merged by `version`; `clock.nextPhaseAt` schedules the 09:15 Confirm enable via the injectable clock.
- **dev-perf:** portfolio controller takes an `AppSnapshot?` seed, rows stale and display-only until REST, orders never cached, reports structural dirtiness to `SnapshotStore`. I drop my `screenVisibleProvider` ask and use TickerMode pausing with `ref.onCancel` / `ref.onResume`.

**Critiques posted**
| To | Point | Ask |
|---|---|---|
| dev-realtime | Frame-level `asOf` confirms every value every 250 ms; if `ChainRow`/`OptionCell` store it, all 82 cells get new instances and rebuild each frame (breaks NFR-5) | Keep `asOf` out of cell equality: chain-level `asOf` + `ex` map; cell instance changes only on data or `ex` change |
| dev-realtime | Order frame has no idempotency key; on a dropped ack (FR-122) I cannot match the frame to the Placing sheet | Add `clientKey` to `order` frames and `GET /orders?key=K` (also serves Refresh status for a Pending row with no server id) |
| dev-ai | Actions with strike+expiry make the ticket rebuild ids | Always send full `instrumentId`; unknown/expired → "Contract data unavailable" |
| dev-ai | A server-baked `limitPrice` on an old card is stale by tap time | Default 1 lot, no `limitPrice` from cards |
| dev-perf | Ticket opened after the opaque risk-notice route would start blind if it borrowed the chain's quote | Ticket and alert-create controllers own their quote sub; keep the 300 ms linger across the hand-off |
| dev-perf | Marking `origin: resumed` on a quick tab flick (inside linger) flashes every chain cell stale and rebuilds twice | Mark resumed only if the unsubscribe was actually sent; "dirty" = structural change, not LTP ticks |

**Changes to this proposal**
- Section 3: per-cell `select` reads `rows[strike]?.ce/pe` from dev-realtime's `Map<int, ChainRow>`; cell stale flag = `Freshness.of(chainAsOf or ex[id], ...)` re-evaluated on the 250 ms timer, emitted only on flips. My own range debounce is removed.
- Section 4: send-time check calls `Freshness.of`; Placing resolves early on an `order` frame with matching `clientKey` (pending dev-realtime agreement; fallback is the same-key retry result).
- Section 7: `screenVisibleProvider` ask withdrawn; `OrderTicketArgs` / `AlertArgs` / `ChainArgs` names follow dev-ai.
- Ticket controller subscribes to its traded contract and underlying itself (quote path, ref-counted).
- ATM row height (48 vs 52 dp) is with the visual designer; section 3 assumes 48 until answered.
