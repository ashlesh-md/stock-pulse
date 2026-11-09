# 03b Part 11: Chart chrome, Kite-like (v2.0)

Owner: ui-designer. Source: PRD v1.4 section 4.8a (FR-130 to FR-152), Kite chart study. Colour rule from 2.3 still holds: up/down colours are for price direction only, so **no indicator or drawing uses green or red**.

## 11.1 Toolbar

One row under the symbol header, 48 dp high, horizontally scrollable (never wraps), `surface0`, 1 dp `outline` below. Left to right:

| Slot | Control | Behaviour |
|---|---|---|
| Range | chips `1D 1W 1M 3M 6M 1Y 5Y` (`SegmentedChoice`-style chips, 36 dp visual, 48 dp hit) | Selected chip has `accent` text, 1 dp accent outline and w700 |
| Interval | `SpPicker.sheet` compact, value `5m` | Sheet lists 1m 5m 15m 1h 1d 1w; options not valid for the range are disabled with a reason |
| Chart type | `SpPicker.sheet` compact with icon (candles, Heikin-Ashi, OHLC, line, area, hollow) | Sheet rows show a 24 dp type icon |
| Studies | button `Studies` (fx icon) with a count badge | Opens the Studies sheet (11.2) |
| Draw | pencil icon toggle | Enters draw mode (11.5); filled icon plus accent underline when on |
| Settings | gear | Log scale, gridlines, extended price line (sheet with switches) |
| Expand | expand icon, pinned at the right edge | Landscape full-screen (11.7) |

Order of tab stops equals visual order. Every icon button has a tooltip and a semantics label. At 1.3x text and above the labels collapse to icons plus the sheet titles; the row keeps 48 dp.

## 11.2 Studies sheet and indicator chips

- Sheet title `Studies`, search field, list grouped Overlay (SMA, EMA, VWAP, Bollinger) and Lower pane (RSI, MACD). Each row: name, one-line description, `+` add button (48 dp). Tapping a row opens parameter edit (period `SpPicker` or number stepper, 48 dp +/-).
- **Limit:** 4 studies at a time (PRD). The fifth attempt disables every `+` and shows the inline line (not a snackbar) in `warn`: `You can use up to 4 studies. Remove one to add another.`
- **Indicator chips** sit in a row overlaying the top-left of the plot (max 2 lines, wraps), each 32 dp visual / 48 dp hit: colour swatch (10 dp circle) plus `RSI 14` plus an `x` remove. The chip is `surface1` at 90% with 1 dp `outline`; text `textPrimary`. Tap the chip body edits parameters; tap `x` removes (with a 4 s undo through the one-snackbar service).

### Indicator palette (slots)

Chosen away from up/down hues (green about 150 deg, coral red about 5 deg) and from the accent blue (about 210 deg). Slots are assigned in order added and kept per symbol. Contrast is WCAG relative luminance ratio against the chart plot background (`surface0`) and chip/sheet (`surface1`); a line needs 3:1, text swatch labels use `textPrimary`.

| Slot | Name | Dark value | on surface0 / surface1 | Light value | on surface0 / surface1 |
|---|---|---|---|---|---|
| `ind1` | Violet | `#B79CFF` | 8.30 / 7.50 | `#6B46C1` | 6.42 / 5.88 |
| `ind2` | Cyan | `#4FD1E8` | 10.46 / 9.46 | `#0E7490` | 5.36 / 4.91 |
| `ind3` | Magenta | `#F28BC8` | 8.38 / 7.58 | `#B0307C` | 5.90 / 5.40 |
| `ind4` | Yellow / ochre | `#E3D04F` | 12.07 / 10.91 | `#7A6200` | 5.87 / 5.38 |
| `indNeutral` (signal lines, guides) | Slate | `#9AA7B8` | 7.74 / 7.00 | `#566274` | 6.19 / 5.66 |

Every pair clears 4.5:1, so the colours also work as small labels. Shape is the second cue: slots also differ by dash (solid, dash 6-3, dot 2-3, dash-dot) so a colour-blind user, or one who sees violet and magenta alike, can still tell lines apart; the legend chip always carries the name and the period. Price series stays `textPrimary` (line) or up/down candles; VWAP uses `ind4` dashed.
Tokens to add to `SpColors` (dart owner: dev-trading): `ind1..ind4`, `indNeutral`, plus `drawing` (= `info`) and `crosshair` (= `textSecondary`).

## 11.3 Lower panes: RSI and MACD

- Pane min height **64 dp**, default 25% of the chart area, drag divider handle 24 dp tall (hit area 48) to resize between 64 dp and 40% of the chart. Max two lower panes (4-study total still applies).
- Shared time axis and crosshair with the price pane; the crosshair line runs through all panes.
- **RSI:** line in the slot colour, 1.5 dp; guide lines at 30 and 70, 1 dp dashed `outline`, labels `30` `70` `caption` `textTertiary` on the right axis (non-numeric context, but tabular figures). The overbought band above 70 and oversold below 30 use `infoTint` and `surface1` respectively (not red/green). Pane title row: `RSI 14   58.4` using the readout style.
- **MACD:** MACD line slot colour, signal `indNeutral` dashed, histogram bars in `textTertiary` at 50% when below zero and `info` at 50% above (direction of momentum is not price direction, so no up/down colours).
- Each pane has its own y-axis (right, 4 ticks), no animation, repaint inside a `RepaintBoundary`.

## 11.4 OHLC readout row

- Sits directly above the plot, 28 dp high (grows with text scale), `surface0`, always visible. Content: `O 2,412.30  H 2,421.00  L 2,408.55  C 2,419.40  Vol 1.2M  +0.62%` then each active study value in its own slot colour, e.g. `SMA 20 2,401.10`.
- Reads the **last candle** by default; during a long-press crosshair it reads the candle under the finger and shows its time (`10:15`). Values are tabular figures (`price` style, 12 sp, minimum 11 sp), labels `O H L C` in `textTertiary` caption.
- Change cell uses the `ChangeChip` rules (arrow, sign, `up`/`down` text). The readout is one `Semantics` node: `Candle 10:15, open 2412.30, high 2421.00, low 2408.55, close 2419.40, volume 1.2 million, change plus 0.62 percent`.
- **Stale or closed:** when the feed is stale (age over 5.0 s) the row gets a trailing `as of 10:42:07` caption in `warn` (same time format as `StaleBadge`, never an age counter); when the market is closed it reads `as of 15:30:00` in `textSecondary`. The last value stays visible; it is never blanked.
- Narrow screens (below 360 dp or large text): wraps to two lines, OHLC on line one, volume, change and studies on line two (horizontal scroll is not used for a readout).

## 11.5 Drawing mode and handles

- Entering draw mode shows a 48 dp tool strip above the toolbar: `Horizontal line`, `Trend line`, `Fib retracement`, `Delete`, `Done`. Plot pan and zoom are suspended while a tool is armed; `Done` or back exits.
- Drawing stroke 1.5 dp (2 dp selected), colour `drawing` token (`info`: `#6CB4FF` dark, `#0B5CAD` light), Fibonacci levels in `indNeutral` with labels.
- **Handles:** a 12 dp filled circle with a 2 dp `surface0` ring, **44 dp** touch target (transparent), shown on the selected drawing only at its anchor points; the horizontal line has one handle at the right end plus a price tag on the right axis (`price` style, `info` fill, `onAccent`-like text with at least 4.5:1: `#06121F` on `#6CB4FF` 8.6:1; light `#FFFFFF` on `#0B5CAD` 6.67:1).
- Dragging a handle shows the live price at the crosshair-style tag; haptic `selectionClick` on grab only. Tap empty plot deselects; tap a drawing selects it (hit slop 22 dp around the stroke). `Delete` removes the selected drawing with undo.
- Drawings are saved locally per symbol and range-independent (anchored to time and price). They never block Buy/Sell.

## 11.6 Crosshair

Long-press shows a 1 dp `crosshair` line pair (dashed), time tag on the x axis and price tag on the y axis (`surface2` fill, `textPrimary`, tabular). No easing; follows the finger. Lifting the finger hides it after 2 s or on tap.

## 11.7 Landscape full-screen layout

- Entered by `Expand` or device rotation on the chart; system bars hidden (immersive), safe-area insets respected on notch sides.
- Layout (left to right): plot area fills the width; a **right rail** 56 dp wide (inside the safe area) holds, top to bottom: `Exit` (collapse icon, 48 dp), symbol and LTP summary (`PriceCell`), `ConnectionBadge`/`StaleBadge`, then pinned **Buy** (`buy`, 48 dp) and **Sell** (`sell`, 48 dp) at the bottom of the rail. Toolbar becomes a 40 dp overlay strip at the top of the plot, auto-hidden 3 s after the last touch and restored by a tap; OHLC readout stays visible.
- The stale rule is unchanged: a stale price shows the `StaleBadge` in the rail and a disabled confirm applies once the sheet opens; Buy and Sell open the same order sheet (as a side sheet, max 360 dp wide, from the right) and Confirm keeps the `Price not live since hh:mm:ss` reason line above it.
- Lower panes keep the 64 dp minimum; the plot area is at least 60% of the screen height. Studies sheet and pickers open as side sheets 360 dp wide in landscape.
- Rotating back restores the portrait layout and the same selection, crosshair off. No state is lost; layout swap has no animation beyond the platform rotation.
