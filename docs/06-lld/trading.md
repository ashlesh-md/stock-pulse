# 06 · LLD: trading screens (dev-trading)

Version **v2.0** (R-2: application layer, DI folders, feedback, strings, assets, go_router via app/router; sections 2, 4, 4a, 4b). v1.1: LLD review T1–T8. Inputs: PRD v1.1, UX v1.3, 03b v1.3, TRD (TR-1…26), HLD §4, §8, §9, §10.2 **v1.1**,
ADR-0003/0004/0008, `06-lld/README.md` decisions D1–D13.

**v1.1 changes**
- T1 (D1): `openChain` pops to the first route, then `appShellControllerProvider.notifier.select(ScreenId.options)`; no `shellTabProvider`.
- T2 (D2): `MarketRepository.getInstrument(id)` (404 → "Contract data unavailable").
- T3 (D2): portfolio uses `watchPositions()`, `watchHoldings()`, `watchFunds(): Stream<Funds>`, `settlements`, plus `get*` and `getOrders`/`cancel`.
- T4 (D6): `ChainRequest(underlying:, expiry:, fromStrike:, toStrike:)`; iv/delta always present.
- T5 (D4): every pushed route sets `RouteSettings(name: ScreenId.x.name)`; `openStock` uses `pushReplacement` when the top route is `stockDetail`.
- T6 (D5): Add to strategy calls `addLeg(contractId, side, cell.ltp)` and handles `full` / `otherChain`.
- T7 (D10): `AlertArgs.condition: AlertCondition?`; `AlertsRepository.create(symbol, cond, level)`, `list`, `delete`, `watchAll`.
- T8 (D3): pure `PortfolioSummary.compute(positions, holdings, quotes)` (also used by dev-perf's seed); FR-83 traced on `ConnectionBadge`.
- D13: FR-28 (PCR / max pain) is deferred to v2.1 and is not on the chain header.
Covers HLD §10.1 for dev-trading: theme and `MarketColors` migration, openers/args, watchlist and stock page screens, option chain,
order ticket state machine, risk notice, portfolio/orders, alerts UI and banner queue, haptics channel, the tab contents.
**Not here:** `AppShell` and `ScreenVisibility` (dev-perf), repositories, `MarketSocket`, `freshnessOf` (dev-realtime), AI and builder (dev-ai).
Rules: manual Riverpod 3 providers, hand-written immutable classes (`==`, `hashCode`, `copyWith`, `List.unmodifiable`), no codegen,
one controller per screen, `ref.read` only in callbacks, `ref.mounted` after every `await`, no `BuildContext` in controllers.

## 1. Binding interfaces used (HLD §10.2, cited verbatim)
```dart
Freshness freshnessOf({required DateTime? asOf, required bool fromCache, required DateTime serverNow,
  required bool socketLive, required MarketPhase phase});
final freshnessTickProvider = StreamProvider.autoDispose<DateTime>(...); // serverNow every 250 ms
final networkStatusProvider = StreamProvider<NetworkStatus>(...);
final marketClockProvider = StreamProvider<MarketClockState>(...);
final serverClockProvider = Provider<ServerClock>(...);
final liveQuoteProvider = StreamProvider.autoDispose.family<Quote, ({String id, int throttleMs})>(...);
class ChainView { String chainId; int seq; DateTime asOf; double spot; int atm; ChainStatus status;
  List<int> strikes; Map<int, ChainRow> rows; Map<String, DateTime> exAsOf; DateTime asOfFor(String contractId); }
abstract interface class ChainFeed { Stream<ChainView> get views; void setVisibleRange(int fromStrike, int toStrike); }
ChainFeed ChainRepository.watchChain(ChainRequest req);
Future<Result<List<Expiry>>> ChainRepository.expiries(String underlying);
Future<PlaceOutcome> OrderRepository.place(OrderRequest req, {required String idempotencyKey, Duration timeout});
Future<Result<Order?>> OrderRepository.getOrder({String? id, String? clientKey});
Stream<Order> get OrderRepository.updates;  Stream<void> get OrderRepository.resyncCompleted;
Stream<PriceAlert> get AlertsRepository.triggered;  // deduped by alertId against LocalPrefs.seenAlertIds
// v1.1 additions
Future<Result<Instrument>> MarketRepository.getInstrument(String id);                 // v1.1 (404 → "Contract data unavailable")
Future<Result<List<Order>>> OrderRepository.getOrders();  Future<Result<Order>> OrderRepository.cancel(String id);   // v1.1
Stream<List<Position>> PortfolioRepository.watchPositions();  Stream<List<Holding>> PortfolioRepository.watchHoldings();
Stream<Funds> PortfolioRepository.watchFunds();  Stream<Settlement> get PortfolioRepository.settlements;
Future<Result<List<Position>>> getPositions(); Future<Result<List<Holding>>> getHoldings(); Future<Result<Funds>> getFunds();
enum AlertCondition { above, below }
Future<Result<List<PriceAlert>>> AlertsRepository.list();  Stream<List<PriceAlert>> AlertsRepository.watchAll();   // v1.1
Future<Result<PriceAlert>> AlertsRepository.create(String symbol, AlertCondition cond, double level);
Future<Result<PriceAlert>> AlertsRepository.delete(String alertId);
final appShellControllerProvider = NotifierProvider<AppShellController, AppShellState>(...);  // v1.1: .notifier.select(ScreenId tab), tabs only
class AlertArgs { String instrumentId; AlertCondition? condition; double? price; OrderSource source; }   // v1.1 (D10)
enum AddLegResult { added, full, otherChain }
AddLegResult StrategyDraftRepository.addLeg(String contractId, OrderSide side, double premium);  // v1.1: otherChain changes nothing
final screenVisibleProvider = Provider.family<bool, ScreenId>(...);
final snapshotProvider = FutureProvider<AppSnapshot?>(...);
final localPrefsProvider = FutureProvider<LocalPrefs>(...);
```
Owned by me and published exactly as in §10.2: `OrderSource`, `OrderTicketArgs`, `AlertArgs`, `ChainArgs`, `openOrderTicket`,
`openChain`, `openAlertCreate`, `openStock`, `PortfolioSummary.compute`, `SpColors`, `SpTypography`, `SpThemeX`, `Haptics`. Gaps are listed in §13.

## 2. File layout (`stock_pulse/lib/`, v2.0: HLD v2.1 §4, ADR-0009/0010, CR-2 structure rules)
```
core/feedback/     domain/feedback_message.dart (FeedbackKind, FeedbackPriority, FeedbackAction: OpenLocation | ReplyToSender, FeedbackReply, FeedbackMessage)
                   application/feedback_controller.dart · application/open_sheet_count.dart
                   di/feedback_providers.dart (feedbackControllerProvider, openSheetCountProvider)
                   presentation/feedback_host.dart (the only showSnackBar caller)
core/l10n/         app_strings.dart (AppStrings, appStringsFor, defaultLocale, supportedLocales) · app_strings_delegate.dart
                   l10n_context.dart (context.strings) · plural.dart · di/l10n_providers.dart (localeProvider, stringsProvider)
                   strings/{common,market,order,portfolio,error}_strings.dart (+ errorText) · locales/en/*_strings_en.dart
core/assets/       app_icons.dart (AppIcons) · app_images.dart (AppImages, brand SVG paths + all)
core/platform/     domain/{haptics,haptic_dedupe}.dart · data/{method_channel_haptics,noop_haptics}.dart · di/platform_providers.dart
core/theme/ core/widgets/ core/format/   unchanged kits; SpSnack folded into FeedbackHost; ErrorView takes the error object
features/market/
  domain/instrument_id.dart (was core/navigation)
  application/     watchlist_{state,controller}.dart · stock_detail_{state,controller}.dart · live_quote_provider.dart (dev-realtime)
  di/market_providers.dart   watchlistControllerProvider, stockDetailControllerProvider (data providers: market_data_providers.dart)
  presentation/screens/   watchlist_screen.dart · stock_detail_screen.dart (scaffold only)
  presentation/widgets/   quote_tile · market_breadth · stock_header · stock_chart_toolbar · stock_chart · range_bar · stock_stats
                          stock_depth · market_depth · trade_bar · order_sheet · candle_chart (gestures + crosshair state)
                          candle_painter (pure paint) · candle_geometry (pure maths, axis labels) · chart_labels (enum → text/icon)
features/orders/domain/order_ticket_args.dart (OrderSource, OrderTicketArgs)
features/alerts/domain/alert_args.dart · features/options/domain/chain_args.dart (toQuery/fromQuery: u, e, k, r)
features/portfolio/
  application/     portfolio_{state,controller}.dart · order_announcer.dart (later fills/cancels → feedback) · order_summary.dart
  di/portfolio_providers.dart   portfolioControllerProvider, orderAnnouncerProvider
  presentation/screens/portfolio_screen.dart · widgets/{pnl_card,section_header,position_tile,order_tile,order_update_listener}.dart
deleted:           core/navigation/** (args → feature domains, openers → app/router AppRoute + context.goTo/pushTo, chain_target gone)
```
One public widget per file; screens hold no private widget classes. No file over 300 lines (painter 297).

## 3. Theme (TR-19, ADR-0008)
| Class | Content |
|---|---|
| `SpColors extends ThemeExtension<SpColors>` | Fields (all `Color`): `surface0, surface1, surface2, outline, textPrimary, textSecondary, textTertiary, accent, onAccent, up, down, warn, info, buy, sell, onSell`. Getters `upTint, downTint, warnTint, infoTint` = token at 14 % alpha. `static const dark`, `static const light` with 03b §2 hex values. `directionOf(num change)`: `> 0` up, `< 0` down, `0` textSecondary. `copyWith` (all named, nullable), `lerp` (`Color.lerp` per field; `other is! SpColors` → `this`) |
| `SpTypography extends ThemeExtension<SpTypography>` | `price, priceDense, change, strike, caption` (`TextStyle`), each with `FontFeature.tabularFigures()`; platform default font (TRD §1.1: no bundled font); `copyWith`, `lerp` via `TextStyle.lerp` |
| `SpSpace` / `SpRadius` / `SpDensity` | `abstract final class` consts: `s1…s8 = 4, 8, 12, 16, 20, 24, 32, 48`, gutter 16, chainGutter 12; radius `s 6, m 10, l 16, pill 999`; `watchlistRow 56, chainRow 48, positionRow 64, tap 48, confirm 52, sectionHeader 32` |
| `AppTheme` | `static ThemeData dark()` / `light()`: explicit `ColorScheme` (surface = surface0, primary = accent, onPrimary = onAccent, error = down, onSurface/onSurfaceVariant = text primary/secondary, outlineVariant = outline, surfaceContainerLow/High = surface1/2); component themes: `SegmentedButtonThemeData`, `BottomSheetThemeData` (radius L top, drag handle), `SnackBarThemeData` (floating), `NavigationBarThemeData` (80 dp, `alwaysShow`), `InputDecorationTheme` (filled surface2, radius M), `DividerThemeData`; `extensions: [SpColors.x, SpTypography.x]` |
| `SpThemeX on BuildContext` | `sp` = `Theme.of(this).extension<SpColors>()!`, `spText` likewise |

`themeMode`: `ThemeMode.system` (Settings override is dev-perf's More shell; it reads a prefs field when added).
**Migration of v1 `MarketColors`** (one PR, step 1 of HLD §10.3):
1. Add `core/theme`, wire `AppTheme.dark()/light()` into `MaterialApp` (replaces `colorSchemeSeed: 0xFF00B386`, forced dark).
2. `SpPriceCell(value, text, lastTickAt, lastDirection, isStale)` replaces `TickPrice`: up/down tint only while `serverNow − lastTickAt < 1.5 s`, computed at build (no timer; the next tick or freshness flip rebuilds); `RepaintBoundary` in chain cells.
3. `QuoteTile` → `QuoteRow` using `context.sp.directionOf`; `ChangeChip` replaces ad-hoc change text.
4. `ConnectionBadge`: dot + text, `warn` for Reconnecting/Offline, no `Colors.*`, semantics label.
5. Delete `core/widgets/market_colors.dart` and `tick_price.dart`; update `tick_price_test.dart` → `sp_price_cell_test.dart`.
6. CI: `tool/ci/theme_grep.sh` fails on `MarketColors` anywhere or `Colors\.` outside `lib/core/theme/` (no exceptions; a transparent colour comes from `SpColors`).
7. Goldens (test font via `FontLoader`): QuoteRow, ChainRow (ATM, ITM, stale, selected), OrderTicket, PositionRow in dark and light at 1.0× and 2.0×.

## 4. Navigation (v2.0: go_router, ADR-0015 as amended by CR-2)
- Routes are not in features: `lib/app/router/` (dev-perf) owns `sealed class AppRoute` and `context.goTo` / `pushTo`.
  Trading screens use `WatchlistRoute()`, `PortfolioRoute({tab})`, `StockRoute(instrumentId)`; the watchlist row calls
  `context.pushTo(StockRoute(id))`, which replaces a stock page on top (D4 rule kept, in `navigation.dart`).
- Args live in their feature `domain/`; `ChainArgs.toQuery()` / `fromQuery()` are pure (empty `u` → null, bad `k`/`r` → null field).
- Order ticket, alert create and risk notice openers arrive with S-28a, S-43, S-30 as `AppRoute`s or sheets.

## 4a. Feedback (ADR-0019 v2.2)
- Only controllers call `feedbackControllerProvider.notifier.show`; `FeedbackHost` (mounted by dev-perf in the router builder, `onOpenLocation` → `router.go`) renders it, hides before showing, reports `dismissed` on close.
- Rules in the controller: same key as shown or shown < 4 s ago (`Clock`) → dropped; priority ≥ shown replaces; lower waits in one slot (newest wins); `clear`; `ReplyToSender` → `replies`.
- Durations 4 s, 6 s with an action, `persist` until closed. Icons `AppIcons.info/success/error`.
- Keys `<feature>.<reason>[.<id>]`:

| Key | Sender | Kind / priority |
|---|---|---|
| `orders.placed.<orderId>` | `StockDetailController.placeOrder` | success / info |
| `orders.<status>.<orderId>` (complete, cancelled, rejected) | `OrderAnnouncer` (status changed after creation) | success, info, error (persist) / orderOutcome |
| `portfolio.cancelFailed.<orderId>` | `PortfolioController.cancel` | error / error |
- A failed order inside the sheet is an inline error above the button (03b 12.1), text from `placeOrder`'s return value.

## 4b. Strings and assets (ADR-0018)
- Areas owned here: `common` (core widgets), `market`, `orders`, `portfolio`, `errors`. dev-ai adds `ai`/`studies`, dev-perf `more`: one interface file, one `en` table, one getter line in `app_strings.dart` and `app_strings_en.dart`.
- Widgets: `context.strings.<area>.x`; controllers: `ref.read(stringsProvider)`; errors: `errorText(strings.errors, error)` (never `AppError.message`).
- Enum labels (`ChartType`, `CandleInterval` units) map to strings in `chart_labels.dart`; range codes (`1D`) and interval codes (`5m`) are symbols.
- Dates and numbers only through `Fmt` (added `date`, `dayMonth`, `monthYear`).

## 5. Watchlist and stock page (FR-1…FR-6, FR-10…FR-14)
| Controller (provider) | State fields |
|---|---|
| `WatchlistController` `AsyncNotifierProvider.autoDispose` | `WatchlistState{instruments: List<Instrument>, quotes: Map<String, Quote>, staleIds: Set<String>, lastTickAt: Map<String, DateTime>, fromCache: bool}` |
| `StockDetailController` `AsyncNotifierProvider.autoDispose.family<…, String>` | `StockDetailState{instrument, quote: Quote?, isStale: bool, candles, interval, chartType, depth: Depth?, phase: MarketPhase}` |

- Watchlist seeds from `snapshotProvider` (cached quotes `fromCache: true` → stale until a live frame, FR-81), then REST, then
  `MarketRepository.watchQuotes(ids, FeedMode.quote)`; marks structural dirtiness via `SnapshotStore.markStructuralDirty()` only on list changes.
- **Lifecycle pattern (ADR-0004, used by every price controller in this LLD):** in `build`,
  `ref.listen(screenVisibleProvider(ScreenId.watchlist), (_, visible) => visible ? _attach() : _detach(), fireImmediately: true)`;
  `_attach` opens the stream subscription, `_detach` cancels it; state is kept. `ref.onDispose(_detach)`.
- Freshness: when visible the controller `ref.listen`s `freshnessTickProvider`; on each tick and each batch it recomputes
  `staleIds` via `freshnessOf` and emits only if the set changed. Rows select `(quote, stale: staleIds.contains(id))` as a record.
- `QuoteRow` 56 dp `InkWell`+`Row`, long-press / `⋮` → `RowActionsSheet` (Buy, Sell, Chart, Option chain, Set alert; NIFTY: last three, FR-4, FR-6).
- Stock page: `TradeBar` pinned bottom (Buy blue / Sell red, 52 dp, enabled when stale or closed, FR-12) → `openOrderTicket`;
  "Option chain" → `openChain(ChainArgs(underlying: id))` (FR-13); `MarketStatusPill` from `marketClockProvider` (FR-14);
  index kind hides Buy/Sell and depth (FR-6). Visibility id `ScreenId.stockDetail`.

## 6. Option chain (FR-20…FR-29c, NFR-5, TR-7, TR-8)
**Controller** `optionChainControllerProvider = AsyncNotifierProvider.autoDispose<OptionChainController, OptionChainState>`
(kept alive by the built Options tab).

```
OptionChainState {
  String underlying; List<Expiry> expiries; String expiry;
  ChainView? view;               // from ChainFeed.views, used as-is (no delta folding here)
  Set<String> staleIds;          // contracts whose freshnessOf != live; emitted only on change
  bool feedStale;                // socket not live (all cells dim + banner)
  int oiMax;                     // max oi over view.rows, recomputed per view
  Set<ChainColumn> columns;      // default {oi, oiChange, ltp}; picker adds iv, delta (FR-21)
  MarketPhase phase; int? selectedStrike; OptionRight? selectedRight;
  int centreEpoch;               // +1 when the list must jump (open, expiry/underlying change, target)
  int? centreStrike;             // ATM or the ChainArgs target strike
  String? expiredNotice;         // "11 Nov expired · showing 18 Nov" (FR-29c), consumed by the screen
}
```
Commands: `selectExpiry(String)`, `selectUnderlying(String)` (writes `LocalPrefs.lastChainUnderlying`, FR-29b),
`setColumns(Set<ChainColumn>)`, `selectCell(int strike, OptionRight right)`, `onVisibleRange(int firstStrike, int lastStrike)`
→ `_feed.setVisibleRange(first, last)` raw (debounce 250 ms and ±5 buffer live in `ChainRepository`, architect decision), `retry()`.

**Build:** underlying = `chainTargetProvider` target ?? `prefs.lastChainUnderlying` ?? `NIFTY`; `expiries(underlying)`; nearest
non-expired expiry (or target); `_feed = ChainRepository.watchChain(ChainRequest(underlying: u, expiry: e, fromStrike: strikes.first, toStrike: strikes.last))`
(full 41-strike day set from expiry metadata; the repository narrows to visible ± 5 after the first `setVisibleRange`);
attach/detach on `screenVisibleProvider(ScreenId.options)`. On each `ChainView`: if `status == expired` → move to next expiry,
set `expiredNotice`, `centreEpoch++` (FR-29c); first view or expiry change → `centreStrike = view.atm`, `centreEpoch++`.

**Widget tree and what rebuilds on a tick** (tick = new `ChainView` where only changed `ChainRow`/`OptionCell` instances are new):
```
OptionChainScreen (ConsumerStatefulWidget: owns ScrollController, ValueNotifier<bool> atmVisible)
├─ ChainHeader            select (underlying, spot quote, phase)            → rebuilds when spot changes (FR-25)
│   ├─ ExpiryChips        select (expiries, expiry)                         → expiry change only
│   └─ ColumnPicker       select columns                                    → picker change only
├─ StaleBadge (banner)    select feedStale                                  → flips only
├─ ChainColumnLabels      select columns                                    → const otherwise
├─ ChainList: ListView.builder(itemCount: strikes.length (41), itemExtent: 48, addAutomaticKeepAlives: false)
│   selects view.strikes (identity; fixed per day, FR-20) → never on ticks
│   └─ ChainRow(key: ValueKey(strike), strike) StatelessWidget + RepaintBoundary → never rebuilt by ticks
│       ├─ ChainCell(strike, ce)   select (rows[strike]?.ce, staleIds.contains(ceId) || feedStale, columns,
│       │                           itm: strike < spot, selected)                → only if that cell changed
│       │   └─ OiBar               select (oi * 40 / oiMax).round()             → only when its bucket moves
│       ├─ StrikeCell(strike)      select (isAtm: view.atm == strike)           → 2 rows when ATM moves (FR-23)
│       └─ ChainCell(strike, pe)   same as CE, itm: strike > spot
└─ BackToAtmFab           ValueListenableBuilder(atmVisible)                → flips only (FR-22)
```
Expected per 250 ms tick: changed cells (most visible LTPs, since premiums follow spot) + header; 0 rows, 0 list rebuilds;
keep-alive `ka` frames rebuild nothing (TR-8). A 250 ms freshness tick rebuilds only cells whose stale flag flipped.
Cells are `GestureDetector`s 48 dp tall: tap → `CellActionSheet` (Add to strategy → `addLeg(cell.contractId, side, cell.ltp)` (D5): `added` → snack "Added to strategy · View";
`full` → snack "Up to 4 legs in preview"; `otherChain` → nothing changes, snack "Strategy uses NIFTY 10 Nov · Start new" whose action calls
`clear()` then `addLeg(...)` again; Greeks,
Set alert, Sell, Buy → `openOrderTicket(OrderTicketArgs(side, lots: 1, product: nrml, source: chain))`, FR-26, FR-29);
long-press strike → `GreeksSheet` (`option_math.greeks`, FR-27). ITM tint: surface1; ATM strike cell: surface2 + 2 dp accent rules
drawn inside 48 dp (row height question with the visual designer). Semantics per 03b 5.4; `PaintProbe.mark(seq)` in a post-frame
callback of the probed cell (TR-23).

**ATM without auto-scroll (FR-22, FR-23):** the screen `ref.listen`s `centreEpoch`; on change, after layout,
`jumpTo(clamp(index(centreStrike) * 48 − (viewport * 0.55 − 24)))`. ATM moves never jump. `atmVisible` is updated from a
`NotificationListener<ScrollNotification>` (index range from offset / 48); the same listener calls `onVisibleRange`.
Target from `ChainArgs.strike`: `centreStrike` = target, `selectedStrike/Right` set (2 dp outline, static).

## 7. Order ticket (FR-26, FR-30…FR-39a, FR-92, NFR-8, TR-6, TR-10, TR-21, TR-25)
**Provider** `orderTicketControllerProvider = AsyncNotifierProvider.autoDispose.family<OrderTicketController, OrderTicketState, OrderTicketArgs>`
(`OrderTicketArgs` has value `==`). `build` loads `MarketRepository.getInstrument(args.instrumentId)` (error → `BlockContractMissing`) and `PortfolioRepository.getFunds()` then `watchFunds()`, then attaches quote subs for the
traded contract and (options) the underlying through `MarketRepository.watchQuotes([id], FeedMode.ltp)` (own subs, HLD §8.3);
listens `freshnessTickProvider`, `networkStatusProvider`, `marketClockProvider`, `OrderRepository.updates`.

```
OrderTicketState {
  OrderTicketArgs args; Instrument instrument;        // kind, lotSize, tickSize, bandLow, bandHigh, expiry, strike, right
  OrderDraft draft;                                   // side, product, type, lots|qty, priceText, triggerText
  Quote? traded; Quote? underlying; Freshness tradedFreshness; Freshness underlyingFreshness;
  NetworkStatus network; MarketPhase phase; double? fundsAvailable;
  Map<TicketField, String> fieldErrors; Set<Nudge> dismissedNudges;
  SubmitPhase submit; String? rejection;              // inline banner text
  // getters: int units; double orderValue; double? maxLoss; List<Nudge> nudges; ConfirmBlock? confirmBlock; String confirmLabel
}
OrderDraft { OrderSide side; ProductType product; OrderType type; int quantity /* lots for F&O */; String priceText; String triggerText; }
sealed class SubmitPhase: SubmitIdle · SubmitPlacing(String key, int attempt) · SubmitChecking(String key, int attempt)
  · SubmitPlaced(Order order) · SubmitRejected(String code, String message) · SubmitPending(String key)
sealed class ConfirmBlock(String reason): BlockPlacing · BlockOffline("Offline · reconnecting…") · BlockClosed("Market closed · opens 09:15")
  · BlockPreOpenOption("Options open at 09:15") · BlockContractMissing("Contract data unavailable")
  · BlockStale("Price not live since hh:mm:ss") · BlockInvalid(fieldError)        // priority in this order
```
Defaults: product CNC (equity) / NRML (F&O), MIS offered on both, CNC hidden for F&O (FR-32); lots = args.lots ?? 1; type Limit
with price = LTP rounded to tick when `args.limitPrice` is null. `OrderValidator` (pure): tick multiple, band `[bandLow, bandHigh]`
(FR-34), SL trigger rule (FR-35), qty > 0; returns `Map<TicketField, String>`. Nudges (FR-36): limit > 3 % from LTP, value > 25 %
of funds, expires today, underlying not live (E20); never block. Pre-open: Market segment disabled for equity (FR-37); option Confirm
re-enables at `MarketClockState.nextPhaseAt` via the `marketClockProvider` frame (no reopen).

**State machine**
| From | Event | To | Effect |
|---|---|---|---|
| Idle | `confirm()` and block == null and send-time check live | Placing(key, 1) | `repo.place(req, idempotencyKey: key, timeout: 4 s)` in the same turn; 3 s timer → Checking |
| Idle | `confirm()` and send-time check not live / invalid | Idle | `confirmBlock` set, inputs kept, 0 POSTs (FR-38, NFR-8); `HapticFeedback.lightImpact` + focus reason |
| Placing/Checking | `PlaceAcked(order)` or `updates` frame with `clientKey == key` | Placed(order) or Rejected | first wins; later results for the same key ignored (`_activeKey` guard) |
| Placing/Checking | `PlaceRejected(code, msg)` | Rejected | `TicketEvent.rejected(key)` to the outcome listener (haptic) |
| Placing | 3 s elapsed | Checking(key, attempt) | label "Checking status…", `Semantics(liveRegion)` |
| Placing/Checking | `PlaceTimedOut`, attempt ≤ 2 | Checking(key, attempt+1) | wait 1 s then 2 s (`Clock`-driven timer), retry with **same key** (FR-31) |
| Checking | 3rd timeout | Pending(key) or Placed | one `getOrder(clientKey: key)`: found → Placed/Rejected; else Pending: sheet closes, snack "Order status unknown. See Orders", portfolio adds a Pending row (FR-31a) |
| any in flight | traded becomes stale | unchanged | no cancel (FR-38a) |
| Rejected | any draft edit | Idle | new key on the next confirm |
| Placed | — | — | sheet pops; snack and success haptic come from `OrderOutcomeListener` |

`confirm()` steps (synchronous until `place` is called, TR-6): (1) return unless `submit is SubmitIdle`; (2) `now = ref.read(serverClockProvider).now()`;
(3) `freshnessOf(asOf: _latestTraded.asOf, fromCache: _latestTraded.fromCache, serverNow: now, socketLive: network == live, phase: phase)`
using the controller's latest quote field (not the 250 ms state copy); (4) validator; (5) `key = _key ??= randomKey128()`;
(6) state = Placing; (7) `final f = repo.place(...)`; only then `await f`. Sheet: `PopScope(canPop: submit is SubmitIdle || terminal)`,
drag disabled while locked; Confirm `BlockedConfirmButton` keeps side colour with spinner (03b 5.5a).
Kill mid-submit: nothing persisted, nothing resubmitted; Orders shows `GET /orders` truth on relaunch (E18).

## 8. Portfolio, positions, holdings, orders (FR-31a, FR-39, FR-40…FR-49)
`portfolioControllerProvider = AsyncNotifierProvider.autoDispose<PortfolioController, PortfolioState>` (evolves v1).
```
PortfolioState { PortfolioTab tab; List<Position> positions /* keyed (symbol, product) */; List<Holding> holdings;
  List<Order> orders /* newest first, includes PendingOrder rows */; Map<String, Quote> ltp; Set<String> staleIds;
  Funds? funds; bool fromCache; DateTime? savedAt; List<SystemEvent> events /* square-off, settlement */;
  Set<String> refreshing /* pending keys being refreshed */
  PortfolioSummary summary /* = PortfolioSummary.compute(positions, holdings, ltp) on every change */ }
PortfolioSummary { double invested, current, dayPnl, totalPnl, realisedToday, unrealisedToday;
  static PortfolioSummary compute(List<Position> positions, List<Holding> holdings, Map<String, Quote> quotes); } // pure, FR-45, FR-47
// lives in features/portfolio/domain/portfolio_summary.dart; dev-perf's cache seed calls it (D3: summary is not cached)
```
- Seed from `snapshotProvider` (positions/holdings display-only, stale; orders never cached; summary computed, not read), then
  `getPositions()`, `getHoldings()`, `getFunds()`, `getOrders()`; then `watchPositions()`, `watchHoldings()`, `watchFunds()`,
  `OrderRepository.updates` and `settlements` (→ `SystemEvent` row + snack, FR-49) while `screenVisibleProvider(ScreenId.portfolio)`.
- Merge rule: `Order`/`Position` replaced only if incoming `version` > held (TR-9, TR-10); `resyncCompleted` → REST reload of
  orders, positions, holdings, funds. Pending rows are matched by `clientKey` and swapped to the final order.
- `refreshPending(key)`: `getOrder(clientKey: key)`; enabled unless `network == offline` ("Waiting for connection").
- LTP: `watchQuotes(open position + holding ids, FeedMode.ltp)` under `screenVisibleProvider(ScreenId.portfolio)`; Exit →
  `openOrderTicket(opposite side, full lots/qty, same product, source: position)` (FR-42). Badges "Auto square-off 15:20" for MIS,
  "Expires today" (FR-43). `OrderRepository.cancel(orderId)` for open orders. Structural changes → `markStructuralDirty()`.

## 9. Alerts (FR-50…FR-55)
| Controller | State |
|---|---|
| `AlertsController` `AsyncNotifierProvider.autoDispose` (`list()` then `watchAll()`) | `AlertsState{active: List<PriceAlert>, triggered: List<PriceAlert>, ltp: Map<String, Quote>, pendingDelete: String?}` |
| `AlertCreateController` `AsyncNotifierProvider.autoDispose.family<…, AlertArgs>` | `AlertCreateState{instrument, condition: AlertCondition, priceText, ltp: Quote?, error: String?, saving: bool, network}` |

Default condition = `args.condition` ?? (price ≥ LTP ? above : below); Save → `AlertsRepository.create(instrument.symbol, condition, level)`;
delete → `AlertsRepository.delete(alertId)`. Create validation: tick 0.05; Above > LTP, Below < LTP ("Already above · alert would fire now"); Save disabled Offline. Delete with
4 s Undo snack (delete sent after the snack closes). **Banner queue** (`AlertBannerHost`, app level): listens `AlertsRepository.triggered`
(already deduped by `alertId`, FR-55); if `openSheetCountProvider > 0` → queue + `bellDotProvider = true`; on count → 0 show queued
banners one at a time (8 s, tap → `openStock`), text "(while you were offline)" when `triggeredAt` < last reconnect (FR-54).

## 10. Order outcomes and haptics (FR-100…FR-102, FR-126, TR-21)
- `OrderOutcomeListener` (app-level `ConsumerStatefulWidget`): listens `OrderRepository.updates` and `ticketEventsProvider`
  (`Provider<StreamController<TicketEvent>>`, broadcast; carries rejections that have no order id). For each terminal transition:
  `HapticDedupe.firstTime(key)` with key `(orderId, status)` or `(clientKey, rejected)`; first time → snack + `haptics.success()` /
  `rejection()` when `prefs.data.hapticsEnabled` (FR-102). Dedupe is an in-memory LRU (500) seeded from the first `GET /orders`, so a
  relaunch or resync never re-announces (NFR-10).
- Dart: `const MethodChannel('stockpulse/haptics')`, methods `success`, `rejection`, no args. `MethodChannelHaptics` catches
  `MissingPluginException` and `PlatformException`, calls `CrashReporter.log('haptics_unavailable')` once, then no-ops (FR-101).
  `hapticsProvider = Provider<Haptics>`: `kIsWeb` or macOS/Windows/Linux → `NoopHaptics`, else `MethodChannelHaptics`.
  Tests override with `FakeHaptics` (records calls).
- **Kotlin** (`MainActivity.configureFlutterEngine` → `SpHaptics(activity).attach(flutterEngine.dartExecutor.binaryMessenger)`):
  handler on the main thread; `success` → API ≥ 30 `window.decorView.performHapticFeedback(HapticFeedbackConstants.CONFIRM)`,
  API 26–29 `VibrationEffect.createWaveform(longArrayOf(0, 25, 80, 15), intArrayOf(0, 180, 0, 90), -1)`, below 26
  `performHapticFeedback(LONG_PRESS)`; `rejection` → API ≥ 30 `REJECT`, 26–29 waveform `(0, 40, 120, 40)` amplitude 255/255;
  `!vibrator.hasVibrator()` → nothing; always `result.success(null)`; unknown method → `result.notImplemented()`.
  `VIBRATE` permission in the manifest (normal permission).
- **Swift** (`AppDelegate.didInitializeImplicitFlutterEngine`: `SpHaptics.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "SpHaptics")!)`):
  `FlutterMethodChannel(name: "stockpulse/haptics", binaryMessenger: registrar.messenger())`; one `UINotificationFeedbackGenerator`,
  `prepare()` at registration and after each use; `success` → `.success`, `rejection` → `.error`; `result(nil)`; unknown →
  `FlutterMethodNotImplemented`. No Taptic Engine → the generator does nothing (silent).
- Selection clicks (segments, stepper) use built-in `HapticFeedback.selectionClick()` (03b §7), not the channel.

## 11. Tab contents (shell is dev-perf's)
I provide the five tab roots as `const` widgets with their `ScreenId`: `WatchlistScreen` (watchlist), `OptionChainScreen` (options),
AI (dev-ai), `PortfolioScreen` (portfolio), More (dev-perf; I provide `AlertsScreen` and the risk-notice re-view entry). Each root
shows the global chrome (`MarketStatusPill`, Demo clock chip, `ConnectionBadge` from `networkStatusProvider` with Live /
Reconnecting / Offline (FR-83), FR-90 `StaleBadge` banner). No root builds
anything in `initState` beyond its controller watch, so lazy tabs keep the chain provider at 0 listeners (FR-82).

## 12. Tests (W = widget, I = integration on in-process `TestServer`, U = unit)
| Screen | Test | Traces |
|---|---|---|
| Theme | U `SpColors.lerp/copyWith`, AA contrast table for all text tokens both themes; CI grep; goldens 1.0×/2.0× | TR-19, NFR-12 |
| Watchlist | W 50 rows, one tick on A → A built once, others 0 (build counter); W RELIANCE frozen 5.1 s (FakeClock) → only that row stale; W socket down → all stale; W long-press NIFTY → 3 actions | FR-1, FR-4, FR-5, FR-6, TR-8 |
| Watchlist | I cold start with cache → rows grey until first frame; hidden tab → `/debug/subscriptions` quotes 0 after 300 ms linger | FR-81, FR-86, TR-12 |
| Chrome | W `networkStatusProvider` live → reconnecting → offline: `ConnectionBadge` text and semantics "Live" / "Reconnecting" / "Offline", `warn` not red; I server drop → Reconnecting | FR-83 |
| Portfolio | U `PortfolioSummary.compute`: 3 holdings sums = rows, realised + unrealised today, missing quote skipped | FR-45, FR-47 |
| Navigation | W `openStock` from a stock page → 1 stock route (pushReplacement); W `openChain` from a pushed stock page → stack popped, Options tab selected, target strike centred; route names = `ScreenId` | D1, D4, FR-13 |
| Chain | W Add to strategy: `added`, `full` snack, `otherChain` snack → Start new → `clear` then `addLeg` | FR-29, D5 |
| Stock page | W NIFTY: no Buy/Sell, no depth; W Buy/Sell rects in bottom 25 % ≥ 48 dp at 360×800; W clock 09:10 → "Pre-open" | FR-6, FR-12, FR-14, NFR-13 |
| Chain | W 41 rows; spot moves 3 strikes → row set and `ScrollController.offset` unchanged (±0), 2 strike cells rebuilt; W one cell delta → 1 cell rebuilt; W `ka` view → 0 rebuilds; W oiMax change → only bucket-changed bars | FR-20, FR-23, NFR-5, TR-8 |
| Chain | W open → ATM at 55 % viewport; scroll 10 rows → FAB → tap → centred; W picker adds IV; W cell → sheet → Buy → ticket prefilled 1 lot NRML | FR-21, FR-22, FR-26 |
| Chain | I one chain sub, 0 extra quote subs; scroll → range updated once per 250 ms; expiry day + debug next day → next expiry within 1 s; last viewed RELIANCE reopened | FR-29a, FR-29c, FR-29b, TR-7 |
| Ticket | U `OrderValidator` (tick 101.03, band 120.05 equity, option band, SL rule); U lot fixture 50 → "100 qty · ₹10,000" | FR-33, FR-34, FR-35, NFR-9 |
| Ticket | W two taps 50 ms → 1 `place` call; W FakeClock freeze, Confirm at 5.1 s → 0 POSTs, reason shown; at 4.9/5.0 s → POST; W stale → live → Confirm enabled, inputs kept | FR-31, FR-38, FR-92, NFR-7, NFR-8 |
| Ticket | W stale arising between tap and send (asOf crosses 5.0 s inside `confirm()` with FakeClock) → 0 POSTs | NFR-8, TR-6 |
| Ticket | W 09:14:59.900 option → "Options open at 09:15"; clock frame 09:15:00.000 → enabled without reopen; W underlying stale, contract live → nudge, enabled | FR-37, E20 |
| Ticket | I `dropAckAfterStore` → Checking, retry same key → 1 order on server, 1 fill snack, 1 FakeHaptics `success`; I 3 timeouts → Pending row, snack; resync → Filled, 1 haptic | FR-31, FR-31a, TR-10, NFR-10 |
| Ticket | I `insufficient_funds`, `insufficient_holdings`, `market_closed`, `price_band` → inline banner, 1 `rejection` | FR-30, FR-39, FR-39a, FR-37 |
| Risk notice | W first F&O ticket → notice; Not now → back, shows again; I understand → not again; reset → shows again | FR-113, FR-112 |
| Portfolio | W MIS + CNC RELIANCE → 2 rows; Exit long 2 lots → sell 2 lots prefilled; summary sums = rows; badges at 14:00 | FR-41, FR-42, FR-43, FR-47 |
| Portfolio | I square-off at 15:20 (debug clock) → MIS closed, notice; settlement at 15:30 → ₹6,500 realised; Pending row Refresh enabled while Reconnecting, disabled Offline | FR-44, FR-49, FR-31a |
| Alerts | W create Above below LTP → error; W 2 alerts delete → 1 (after Undo window); W sheet open + trigger → no banner, bell dot; close → banner | FR-50, FR-53, FR-52 |
| Alerts | I same `alertId` live + resync → 1 banner; trigger while disconnected → banner after reconnect | FR-54, FR-55 |
| Haptics | U channel mock (`TestDefaultBinaryMessengerBinding`) receives `success`; `MissingPluginException` → no throw, 1 log; toggle off → 0 calls; fill live + resync → 1 call | FR-100, FR-101, FR-102, FR-126, TR-21 |
| A11y | W 360×800 at 2.0×: watchlist, chain, ticket, portfolio `takeException` null; `textContrastGuideline`, `androidTapTargetGuideline` | NFR-12 |

## 13. Gaps against HLD §10.2 (resolved in v1.1)
1. Shell tab API → D1: `appShellControllerProvider.notifier.select(ScreenId.options)` after `popUntil(first)` (§4).
2. Repository calls → D2: `getInstrument`, portfolio `watch*`/`get*`/`settlements`, `getOrders`/`cancel`, alerts `list`/`create`/`delete`/`watchAll`, cited in §1.
3. TR-21 rejection haptics: `PlaceRejected` has no order id, so the ticket publishes `TicketEvent.rejected(clientKey)` to the listener; dedupe key `(clientKey, rejected)` (approved, local).
