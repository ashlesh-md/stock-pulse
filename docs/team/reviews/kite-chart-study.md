# Kite chart and stock feature study (CR-1.0)

Owner: product manager · 7 Nov 2026 · Feeds PRD v1.4 §4.8a (FR-130…FR-149)

Kite (Zerodha) ships two chart engines on web and mobile: **ChartIQ** (default) and **TradingView** (switch in
Settings). Official docs claim 100+ indicators, 15+ chart types, 30+ drawing tools, Day/Night theme. On mobile,
Trade from Charts (TFC) runs on TradingView charts only. Facts I could not confirm from a Zerodha source are marked
**(unverified)**.

**v1 baseline (already built):** ranges 1D/1W/1M/3M/6M/1Y/5Y, intervals 1m/5m/15m/1h/1d/1w, five types
(candles, Heikin-Ashi, OHLC bars, line, area), volume bars, pinch/pan, double-tap fit, long-press crosshair.

Effort: **S** ≤ 1 dev-day · **M** 2–4 days · **L** ≥ 5 days (incl. tests, goldens, a11y).
v2 call: **Must / Should / Could / Later** (Later = v2.1 or backlog).

## 1. Chart types

| Feature | What it does on Kite | Value for our traders | Effort | v2 |
|---|---|---|---|---|
| Candles, Heikin-Ashi, OHLC bars, line, area | Standard styles; candle is the default | Already in v1 | — | v1 ✅ |
| Hollow candles | Fill shows close vs open, colour shows close vs prev close (ChartIQ style) | Meera reads momentum at a glance; cheap paint variant | S | Could |
| Baseline / mountain variants | Line/area coloured above/below a base (TradingView) (unverified on Kite mobile) | Marginal over area | S | Later |
| Renko, Kagi, Line break, Point & Figure | Time-less, price-move aggregations (ChartIQ "types") | Niche for our personas; needs box-size settings and server data from lower interval | L | Later |
| Range / volume bars | TradingView only, not confirmed on Kite (unverified) | Niche | L | Later |

## 2. Intervals and ranges

| Feature | What it does | Value | Effort | v2 |
|---|---|---|---|---|
| Ranges 1D–5Y, 6 intervals | Range chips + interval picker; mobile default 5m | v1 ✅ | — | v1 ✅ |
| Extra intervals (3m, 10m, 30m, 2h, 4h, 1M) | Kite lists many more minute/hour steps | Arjun uses 3m/30m sometimes; server bucket work | M | Later |
| Remember last range/interval/type per user | Kite keeps chart state between opens | Saves taps on 3–5 opens a day (Meera) | S | Should |

## 3. Indicators (Studies menu, searchable, removable with X)

| Feature | What it does | Value | Effort | v2 |
|---|---|---|---|---|
| Volume | Volume bars under price (v1 has them) | Confirms moves | — | v1 ✅ |
| SMA (period N) | Simple moving average overlay | Most-used trend line for learners (Rohan) | S | **Must** |
| EMA (period N) | Exponential MA overlay | Intraday standard (9/21 EMA) for Arjun | S | **Must** |
| VWAP | Session-anchored volume-weighted price, intraday only | Key intraday reference on Indian desks | S | **Must** |
| Bollinger Bands (20, 2) | SMA ± k·stdev bands | Volatility view, simple maths | S | Should |
| RSI (14) | Oscillator 0–100 in a lower pane | Popular with learners; needs a sub-pane | M | **Must** (pane shared by RSI/MACD) |
| MACD (12, 26, 9) | Line, signal, histogram in a lower pane | Popular; reuses the pane | S after RSI | Should |
| Supertrend (10, 3) | ATR-based trailing band, flips colour | Very popular in Indian retail (unverified as Kite default list item, it is in the library) | M | Could |
| CPR / pivots, Volume Profile | Kite staff confirm CPR on ChartIQ, Volume Profile on both | Niche for v2 personas | M–L | Later |
| 100+ indicator library, custom scripts | Search across the full library; Pine-style scripts not supported on Kite | Out of proportion for a practice app | L | Later |

## 4. Drawing tools (pencil icon, 30+ on Kite)

| Feature | What it does | Value | Effort | v2 |
|---|---|---|---|---|
| Horizontal line | Price level across the chart | Support/resistance; simplest touch UX | S | **Must** |
| Trend line | Two-point line, extends | Core TA drawing | M (touch handles, hit tests) | **Must** |
| Fibonacci retracement | Levels between two points | Popular, reuses two-point handles | S after trend line | Should |
| Rectangles, channels, text, arrows, 25+ others | Full ChartIQ/TradingView set | Diminishing value on a phone | L | Later |
| Saving drawings | Kite: default-layout drawings sync to cloud; users report lost drawings (forum) | Drawings that vanish feel broken | S (local, per symbol) | **Must** (local only) |

## 5. Interaction and readout

| Feature | What it does | Value | Effort | v2 |
|---|---|---|---|---|
| Crosshair | Long-press crosshair; can be toggled off; two-finger pan (Kite docs) | v1 ✅ | — | v1 ✅ |
| OHLC + volume + change readout | Header row shows O H L C, volume, change for the candle under the crosshair (or the last) | Answers what was the price then; essential once crosshair exists | S | **Must** |
| Indicator values in readout | Each active study shows its value at the crosshair | Makes indicators readable on 360 dp | S | **Must** |
| Compare symbols | Overlay another stock/index as % change (TFC post) | Nice (RELIANCE vs NIFTY); second data stream, % axis | M | Could |
| Log scale, gridlines, theme, extended price line | Settings on both engines (log scale unverified on Kite mobile) | Log helps 5Y views; gridlines toggle trivial | S | Should (log + gridlines) |
| Full-screen / landscape | Rotate button; Kite staff call landscape focus mode with search and switching off; users report no depth in landscape | Wider charts for drawing; must keep stale rule and B/S | M | **Must** |
| Quick chart launcher, in-chart search, prev/next symbol arrows | Floating icon, last 20 charts, step through marketwatch (Dec 2025 post) | Prev/next is cheap and handy | S–M | Could (prev/next only) |

## 6. Layouts and trading from the chart

| Feature | What it does | Value | Effort | v2 |
|---|---|---|---|---|
| Save chart layouts | TFC post: up to 10 customised layouts saved locally; multi-chart layouts (TradingView 8, ChartIQ 4 on web) | Per-symbol memory of studies/drawings covers most of it | M | Later (single layout, auto-saved) |
| Buy/Sell from chart | B/S with best bid/ask (TFC); bottom-placed on mobile | Keeps the 2-tap flow from chart; reuse the order sheet | S | **Must** (opens the existing sheet) |
| Long-press a level → limit/SL order at that price | TFC | Good for Meera; must go through the sheet and stale block | M | Should |
| Orders and positions drawn on chart, drag to modify | TFC; pending order lines draggable | Strong but needs modify-order API (not in v2) | L | Later |
| Instant order placement (no confirm) | TFC option | **Conflicts with D-4 and our confirm rule** | — | Rejected |
| Alert from chart | Kite staff: not yet on mobile charts (TFC comments) | We already have alerts; long-press level → Set alert is cheap | S | Should |
| GTT from chart | Not part of TFC; GTT is a desktop shortcut and order-window feature | GTT out of scope (PRD §9) | — | Later |
| Market depth in chart / bottom panel | Depth icon; tap bid/offer opens prefilled window | We show depth on the stock page; panel in chart is extra | M | Later |

## 7. Stock features outside the chart

| Feature | What it does | Value | Effort | v2 |
|---|---|---|---|---|
| Option chain greeks | Kite chain shows greeks and IV (Sensibull-style) | Already FR-21/FR-27 | — | planned |
| Market depth 5-level, tap price to trade | Tap a bid/ask level to prefill | Small extension of FR-11 | S | Could |

## 8. Recommended v2 cut (goes to PRD v1.4)

- **Must:** SMA, EMA, VWAP, RSI (lower pane), OHLC + volume + indicator readout, horizontal line, trend line,
  local per-symbol saving of studies and drawings, landscape full-screen, Buy/Sell from chart via the existing sheet.
- **Should:** Bollinger, MACD, Fibonacci, log scale + gridlines, remember last range/interval/type, alert from a
  chart level, long-press level → limit order sheet.
- **Could:** Supertrend, hollow candles, compare one symbol, prev/next symbol.
- **Later:** Renko/Kagi/P&F/range bars, extra intervals, full indicator library, more drawings, multi-chart and named
  layouts, order lines on chart, depth panel in chart, GTT. **Rejected:** instant order placement.

## Sources

- Kite docs, Charting: https://kite.trade/docs/kite/charting/ · Kite mobile charting: https://kite.trade/docs/kite/kite-mobile/charting/
- Z-Connect, Trade from Charts on Kite app: https://zerodha.com/z-connect/business-updates/introducing-trade-from-charts-tfc-on-kite-app
- Z-Connect, New charting features on the Kite app: https://zerodha.com/z-connect/kite/new-charting-features-on-the-kite-app
- ChartIQ styles and types tutorial: https://documentation.chartiq.com/tutorial-Chart%20Styles%20and%20Types.html
- Zerodha support, Charts: https://support.zerodha.com/category/trading-and-markets/charts-and-orders/charts
