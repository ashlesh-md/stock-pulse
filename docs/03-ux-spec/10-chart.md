# 03 · UX spec part 10: Stock chart, Kite-style (v2.0)

Owner: ux-designer · Part of `../03-ux-spec.md` v2.0 · PRD v1.4 §4.8a (FR-130…FR-152), NFR-23 · Basis
`../team/reviews/kite-chart-study.md` · Components from 03b (ui-designer): `ChartToolbar`, `StudyChip`,
`DrawingHandle`, `SpPicker` (part 11), `SpSheet`, `SpSnack` (part 12).

Priority tags in this part: **[M]** Must, **[S]** Should, **[C]** Could. A Should or Could item that is not built
is simply absent from the UI: no "coming soon" rows, no disabled placeholders.

## 10.1 Principles for the chart

1. **The chart never lies about what it shows.** The range, interval and type labels always match the candles on
   screen. A new interval shows a small spinner on its chip and the old candles stay until the new ones paint; if the
   load fails the chip goes back to the old value (snackbar "Couldn't load 15m · showing 5m").
2. **Every price on the chart obeys the stale rule** (PRD §3.1). The readout, the last-price axis label and the
   live last candle go grey with "as of hh:mm:ss" exactly when the header price does.
3. **Trading from the chart is the normal order sheet.** No one-tap orders, no drag-to-order (D-4). Every path ends
   on Confirm in the `OrderTicket`, with its stale block and reason line.
4. **Thumb first, eyes first.** Readings (header, readout, study chips) sit above the plot where the eyes are;
   controls (range, toolbar) sit below the plot, nearer the thumb. Buy/Sell stays in the pinned bottom bar.
5. **Gestures always have a button.** Pinch/pan/long-press are shortcuts; every result is reachable by a tap.

## 10.2 Portrait: chart on the stock page (FR-10, FR-130…FR-149)

```
┌────────────────────────────────────────┐
│ ← RELIANCE  [●Open][Live]          🔔  │ app bar
│ ₹1,486.10  ▼ −6.40 (−0.43%)            │ header price (live)
│ as of 10:02:14                         │
├────────────────────────────────────────┤
│ 10:05  O 1,484.00 H 1,488.20           │ ReadoutRow (2 lines max at 1.0x)
│ L 1,483.50 C 1,486.10 V 1.2L −0.43%    │  crosshair candle, else last
│ [SMA 20 1,479.30 ✕][EMA 9 1,485.10 ✕]  │ StudyChips, value inline,
│ [VWAP 1,482.75 ✕][RSI 14 58.2 ✕]       │  wrap to 2 rows max
│ ┌ price plot ────────────────────┐1,490│
│ │   ┃┃ ┃  ┃┃┃   ╱ SMA            │     │
│ │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━│1,500│ horizontal line + axis tag
│ │  ┃ ┃┃  ┃ ┃╱  trend line       │1,486│ last price tag (live)
│ └────────────────────────────────┘1,470│ ~240dp at 360x800
│ ┌ RSI 14 ─────────────────────────┐ 70 │ lower pane ≥ 64dp
│ └─────────────────────────────────┘ 30 │
│ ▁▂▅▃▁ volume                           │
│ 09:15     11:00     13:00     15:00    │ time axis
│ [1D][1W][1M][3M][6M][1Y][5Y]           │ range chips, h-scroll
│ [5m ▾] [Candle ▾] [ƒx] [✎] [⚙] [⤢]     │ ChartToolbar, 48dp
│ [Option chain ›] [Set alert ›]         │
│ Market depth (5) · Stats               │
├────────────────────────────────────────┤
│ [    BUY (blue)   ] [  SELL (red)   ]  │ pinned bar (FR-12, NFR-13)
└────────────────────────────────────────┘
```

### Toolbar (portrait), left to right

| Control | Opens | Notes |
|---|---|---|
| `5m ▾` interval | `SpPicker` sheet: 1m 5m 15m 1h 1d 1w | Intervals not valid for the range are listed disabled with a caption ("Not for 5Y"). [M] |
| `Candle ▾` type | `SpPicker` sheet: Candles, Heikin-Ashi, OHLC bars, Line, Area, Hollow candles [C] | Row shows a 24 dp glyph + name. |
| `ƒx` Studies | Studies sheet (§10.4) | Badge shows the active count, e.g. `ƒx 3`. [M] |
| `✎` Draw | Draw mode (§10.6) | Toggle; selected state = `accent` fill. [M] |
| `⚙` Settings | Chart settings sheet (§10.5) | Log scale, gridlines [S], clear drawings, reset studies. |
| `⤢` Full screen | Landscape route (§10.3) | Also entered by rotating the phone while the chart is on screen (OS rotation lock off). [M] |

Six 48 dp targets with 8 dp gaps = 328 dp, which fits 360 dp with 16 dp margins. At text scale > 1.3 the labels of
the two pickers shorten to their value only (`5m`, `Candle` icon) and the row stays one line; at 2.0 the toolbar
wraps to two rows (pickers on row 1, icon buttons on row 2). The range chips scroll horizontally and the selected
chip is scrolled into view.

**Why below the plot:** the trader changes range and studies a few times per visit but reads the chart constantly.
Controls under the plot are 120 dp closer to the thumb than Kite's top toolbar, and the readout stays next to the
price header so the numbers being compared are together.

### Plot gestures (portrait and landscape)

| Gesture | Result | Button alternative |
|---|---|---|
| Pinch | Zoom time axis | Range chips |
| One-finger pan (normal mode) | Scroll back in time; a `⇥ Latest` pill appears at the right edge when the last candle is off-screen | `⇥ Latest` |
| Double-tap | Fit all candles of the range (v1) | `⇥ Latest` then range chip |
| Long-press, then drag | Crosshair (vertical + horizontal line, price tag on the axis, time tag on the time axis); readout follows the candle | Tap a candle in "crosshair on tap" mode (Settings, off by default) |
| Lift after crosshair | Crosshair **stays pinned**; readout keeps that candle; a `⋯` button appears at the price tag | Tap empty plot or `✕` on the readout to clear |
| Two-finger pan (draw mode only) | Scrolls while draw mode keeps one-finger taps for placing | — |

### Readout row (FR-139) [M]

- Content: candle time (`10:05`, or `12 Nov` on 1d+), **O H L C**, volume (lakh/crore short form), change % vs the
  previous candle's close; then each active study's value lives **in its chip** (so the chip is the legend and the
  readout at once, and ✕ is right there).
- No crosshair → the last candle. Last candle while stale → the time is replaced by `⏱ as of 10:02:14` in `warn`
  and C is dimmed. A crosshair on a closed historical candle is never stale (it is history), so no "as of".
- Study value missing for that candle (inside the first N−1) → `–` (en dash), never 0.
- Values use tabular figures; the row never changes height while the crosshair moves (fixed 2-line box).
- Semantics: the readout is one merged label, read on demand (not a live region): "10:05, open 1,484, high 1,488.20,
  low 1,483.50, close 1,486.10, volume 1.2 lakh, down 0.43 percent; SMA 20, 1,479.30".

### Crosshair action menu `⋯` [S] (FR-148, FR-149)

Tapping `⋯` at the pinned crosshair price opens a small `SpSheet` (not a popup) titled with the price snapped to
tick, e.g. "RELIANCE at ₹1,512.35":

```
┌────────────────────────────────────────┐
│ ── RELIANCE at ₹1,512.35   LTP 1,486.10│
│ 🔔 Set alert at ₹1,512.35            › │ → alert form prefilled, direction from LTP
│ ━  Draw horizontal line here         › │ [M] (adds the drawing, no draw mode needed)
│ [ Sell limit at 1,512.35 ] [ Buy limit at 1,512.35 ] │ → OrderTicket, Limit, prefilled
└────────────────────────────────────────┘
```

Buy/Sell limit rows only for equities (not NIFTY). Both open the normal ticket: never submits (0 POSTs), Confirm
needed, stale block applies.

## 10.3 Landscape full screen (FR-144, FR-145) [M]

Only this route rotates; the rest of the app stays portrait. Frame ≈ 800 × 360 dp.

```
┌──────────────────────────────────────────────────────────────────────────┐
│ ✕  RELIANCE ₹1,486.10 ▼−0.43% as of 10:02:14 [●Open][Live]   ‹  ›        │ top bar 48dp
│ 10:05 O 1,484.00 H 1,488.20 L 1,483.50 C 1,486.10 V 1.2L −0.43%          │ readout, 1 line
│ [SMA 20 1,479.30 ✕][EMA 9 1,485.10 ✕][VWAP 1,482.75 ✕][RSI 14 58.2 ✕]    │ chips, 1 line, h-scroll
├────┬────────────────────────────────────────────────────────────┬────────┤
│ 1D │                                                            │  1,490 │
│ 5m │   ┃┃ ┃  ┃┃┃   ╱                                            │        │
│ ▥  │ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 1,500 [SELL]│
│ ƒx │                                                            │        │
│ ✎  │ ── RSI 14 ─────────────────────────────────────────── 70   │ [BUY]  │
│ ⚙  │                                                         30 │        │
└────┴────────────────────────────────────────────────────────────┴────────┘
 left rail 56dp (left thumb)            plot                       right rail 88dp
```

- **Left rail** (left thumb): range (opens `SpPicker` list, chips do not fit), interval, type, studies, draw,
  settings. 48 dp targets, 56 dp rail. Order matches the portrait toolbar.
- **Right rail** (right thumb): price axis, then **Sell** above **Buy**, each 48 dp tall × 80 dp, 8 dp apart, Buy at
  the bottom-right corner nearest the thumb (same "Buy last" rule as the row sheet). Equities only; NIFTY shows no
  rail buttons (FR-145).
- Top bar: `✕` exit (top-left; system back does the same), symbol header with the **same** price, change, as-of,
  `MarketStatusPill` and `ConnectionBadge` as portrait. `‹ ›` previous/next symbol in the current watchlist [C]
  (FR-152): keeps range, interval, type; studies and drawings load for the new symbol.
- The stale banner (FR-90) appears as a 32 dp strip under the top bar ("Prices not live since 09:31:07"), never over
  the plot's last candle.
- **Buy/Sell in landscape** opens the `OrderTicket` as a **side sheet**, 400 dp wide, full height, anchored right,
  same content and states as portrait (§3.4 of the main spec). The chart stays visible on the left (dimmed scrim
  40 %), so the trader can see the level they are trading. Confirm is pinned at the sheet bottom; the price field
  uses the stepper first and the keyboard only on tap. Closing returns to full screen with state intact.
- **State kept both ways:** range, interval, type, studies, drawings, crosshair, scroll/zoom position. 0 extra candle
  fetches on rotate (FR-144, NFR-23). Rotating back to portrait while in full screen exits full screen.
- Snackbars in landscape: bottom-left over the plot, max 400 dp wide, never over the right rail.

## 10.4 Studies (indicators) sheet (FR-130…FR-138)

```
┌────────────────────────────────────────┐
│ ── Studies (3 of 4)                    │ SpSheet, 70% height
│ On the price chart                     │ section header
│ SMA  Simple moving average      [ + ]  │ 56dp rows
│ EMA  Exponential moving average [ + ]  │
│ VWAP Volume-weighted avg price  Added ✓│ VWAP: one only
│      Intraday only                     │ caption on 1d/1w
│ BB   Bollinger Bands (S)        [ + ]  │
│ ST   Supertrend (C)             [ + ]  │
│ In a lower pane (up to 2)              │
│ RSI  Relative strength index    Added ✓│
│ MACD Moving average conv./div. (S)[ + ]│
│ Active                                 │
│ SMA 20  ·  EMA 9  ·  VWAP  ·  RSI 14   │ tap = edit, ✕ = remove
└────────────────────────────────────────┘
(S)/(C) tags are spec-only and never shown in the app.
```

- Tap `+` adds the study with defaults (SMA 20, EMA 9, BB 20/2, RSI 14, MACD 12/26/9, Supertrend 10/3), closes the
  sheet and the chip appears. SMA, EMA and BB can be added more than once (e.g. EMA 9 + EMA 21); VWAP, RSI, MACD once.
- **Limits** (PRD §4.8a): at 4 studies every `+` turns disabled with the caption "Up to 4 studies"; a tap on it gives
  the info snackbar "Up to 4 studies · remove one to add another" (key `chart_studies_limit`). 2 lower panes reached →
  pane rows disabled "Up to 2 lower panes".
- **Edit:** tap a `StudyChip` (on the chart or in Active) → study settings sheet: period as a `LotStepper`-style
  stepper (range shown, e.g. "2–200"), presets as segmented chips (SMA: 20 · 50 · 200; EMA: 9 · 21 · 50), colour
  from 4 fixed study colours (03b, auto-assigned in order, editable), and **Remove** (text button, `down` colour)
  at the bottom. Changes apply live behind the sheet; there is no Save button.
- **Remove:** `✕` on a chip removes at once with an Undo snackbar (4 s, key `chart_study_removed`).
- **Not drawable:** VWAP on 1d/1w → chip "VWAP: intraday only", no line. Period > candles → chip
  "Not enough data for SMA(200)", no line (F9). The chip stays so the trader sees why nothing is drawn.
- RSI pane: 0–100 axis, 30/70 dotted guides, value in its chip. MACD pane: line, signal, histogram with up/down
  colour **and** bar direction (shape cue). Pane height ≥ 64 dp at 360 × 800; panes can be resized by dragging the
  12 dp divider (alt: none needed, default heights are fine). Each pane has its own `✕` in the chip, not on the pane.
- Studies, parameters and colours are **saved per symbol** on every change (FR-143).

## 10.5 Chart settings sheet (`⚙`)

| Row | Control | Priority |
|---|---|---|
| Log scale | Switch | [S] FR-146 |
| Gridlines | Switch | [S] FR-146 |
| Crosshair on tap | Switch (off: long-press) | UX addition, local pref |
| Clear drawings on RELIANCE | Text button → confirm dialog "Delete 6 drawings on RELIANCE? · Cancel / Delete" | [M] |
| Reset studies on RELIANCE | Text button → removes all studies, Undo snackbar | [M] |

Range, interval and type are remembered app-wide (FR-147) [S]; studies and drawings per symbol (FR-143) [M].

## 10.6 Drawing tools (FR-140…FR-143)

### Draw mode

Tapping `✎` swaps the toolbar row for the **tool tray** (same position, so the thumb is already there):

```
│ [━ Horizontal] [╱ Trend] [⋮≡ Fib (S)]  [Done] │ tool tray, 48dp
│ Tap the chart to place a horizontal line    │ hint line (caption)
```

- Choose a tool, then:
  - **Horizontal line [M]:** one tap on the plot places it at the tapped price, snapped to tick 0.05. While the
    finger is down a crosshair and price tag show where it will land; lifting places it.
  - **Trend line [M]:** first tap places point A (a handle appears, hint "Tap the second point"), second tap places B.
    Each point is (candle time, price), snapped to the candle centre and tick.
  - **Fibonacci [S]:** like the trend line; levels 0, 23.6, 38.2, 50, 61.8, 100 % with prices on the right.
- After placing, **draw mode ends** and the new drawing is **selected** (one-shot tools avoid accidental extra lines
  when the trader goes back to panning). `Done` or system back leaves draw mode without drawing.
- In draw mode one-finger pan is off; two-finger pan and pinch still move the chart.
- At 20 drawings on the symbol the tools are disabled with the hint "Up to 20 drawings on RELIANCE".

### Select, move, delete

```
│ ━━━━━●━━━━━━━━━━━━━━━━━━━━━━━━━ 1,500.00 │ selected h-line: accent, handle at centre
│     [🔔 Alert] [Buy limit] [Sell limit] [🗑] │ DrawingActionBar, floats above the line
```

- **Select:** outside draw mode, tap within 24 dp of a line (48 dp hit band). Selected = `accent` colour, handles
  shown (12 dp visual, **≥ 44 dp touch**, FR-141), and the `DrawingActionBar` above it (below it if the line is in
  the top 64 dp). Tap empty plot to deselect.
- **Move:** drag a handle (moves that end only) or the line body (moves the whole line; a horizontal line moves only
  vertically). The price tag updates while dragging and snaps on release. Haptic selection tick on snap.
- **Actions:** `🔔 Alert` = "Set alert at ₹X" [S] (h-line only); `Buy limit` / `Sell limit` [S] (h-line only, equities);
  `🗑` delete [M]. Delete is immediate with an Undo snackbar "Line deleted · Undo" (4 s).
- Accessibility: every drawing is a focusable node "Horizontal line at 1,500 rupees" / "Trend line from 10:05,
  1,480 to 13:20, 1,495"; actions are exposed as custom semantic actions (Move up one tick, Move down one tick,
  Delete), so a screen-reader user can adjust a line without dragging.

### Saving (FR-143) [M]

- Auto-saved locally per symbol on every place, move and delete; no Save button.
- Anchored to (time, price): they survive range, interval and type changes, full-screen rotation and restart. An
  anchor outside the visible range is clipped at the plot edge; the line is still there when scrolled back.
- Save failure (F11): drawing stays on screen for this session; one error snackbar "Couldn't save drawing"
  (key `chart_drawing_save_failed`, dropped on repeats).
- "Reset demo account" wipes all drawings and studies (FR-112); the Reset dialog lists "chart drawings and studies".

## 10.7 Buy / Sell from the chart (FR-145) [M]

| From | Opens | Prefill | Tag in ticket |
|---|---|---|---|
| Portrait bottom bar | `OrderTicket` sheet | Side, Market, last qty | — |
| Landscape right rail | `OrderTicket` side sheet | Side, Market | "From chart" |
| Crosshair `⋯` or line bar [S] | `OrderTicket` | Side, **Limit**, price = level snapped to tick | "From chart" |

Always the normal sheet: product, type, qty, risk notice (F&O only, not reachable from an equity chart), stale
block, reason line, Placing/Checking states. NIFTY has no Buy/Sell anywhere on the chart.

## 10.8 Chart states

| State | Plot | Readout / chips | Toolbar | Buy / Sell |
|---|---|---|---|---|
| Load, no cache | Static placeholder box, one centred spinner | Readout `–` values | Enabled; studies can be added and apply when data comes | Enabled; ticket waits for metadata |
| Load, cached candles | Cached candles painted, stale style; live last candle joins on first frame | "as of" on the last candle | Enabled | Enabled (ticket blocks if stale) |
| Changing interval/range | Old candles stay; chip shows spinner | Old values | Picker shows the new value only when painted | Enabled |
| Empty (F9) | `EmptyView` in the plot: "No chart data for 1D yet" + chip "Show 1W" | Hidden | Enabled | Enabled |
| Study not drawable (F9) | Line absent | Chip "Not enough data for SMA(200)" / "VWAP: intraday only" | — | — |
| Error (F3, F5, F6) | `ErrorView` in the plot: "Chart unavailable · Retry"; drawings kept | Hidden | Enabled | Enabled |
| Stale / Offline (F2) | Last candle frozen, last-price axis tag dimmed with ⏱ | Last-candle readout "⏱ as of hh:mm:ss" | Enabled; uncached intervals fail with snackbar and revert | Enabled; ticket blocks with reason |
| Closed / Pre-open | Normal colours | "Closed · as of 15:30:00" / IEP line | Enabled | Enabled; ticket follows FR-37 |
| Server restart (F7) | Reconnecting badge; candles kept; refetch only the gap after resync | Readout updates on live | Enabled | Ticket blocks until live |

Never: a zero-price candle, an empty white plot, a spinner that does not end (timeout → Error after 10 s).

## 10.9 Components needed from ui-designer (03b)

| Component | Needs |
|---|---|
| `ChartToolbar` | 6 × 48 dp, portrait row and landscape rail variants; selected state for `✎`; count badge on `ƒx`; chip-with-spinner state for pickers |
| `StudyChip` | Name + params + live value + ✕ (✕ is its own 48 dp target); colour swatch; disabled/info variant for "intraday only" / "not enough data" |
| `ReadoutRow` | Fixed 2-line (portrait) / 1-line (landscape) box, tabular figures, stale variant |
| `DrawingHandle` + `DrawingActionBar` | 12 dp visual handle in a 44 dp touch area; selected line colour; floating action bar |
| Study colours | 4 colours that pass 3:1 against the plot in light and dark and differ from up/down |
| Crosshair | Line style, axis tags, `⋯` button |
| `SpPicker` | Part 11 |
