# StockPulse v2 Design System (v2.0)

Part files for v2.0 live in `docs/03b-design-system/`:
[10 SpPicker](03b-design-system/10-sp-picker.md) · [11 Chart chrome](03b-design-system/11-chart-chrome.md) · [12 Feedback](03b-design-system/12-feedback.md) · [13 App icon and splash](03b-design-system/13-brand-icon-splash.md) · [14 Assets and strings](03b-design-system/14-assets-strings.md)

## Change log v2.0 (CR-1, PRD v1.4)

| # | Change | Driven by |
|---|---|---|
| V1 | New `SpPicker` (bottom-sheet list and inline segmented variants) replaces every `DropdownButton`; 5.6 `SegmentedChoice` is its inline variant (part 10) | FR-155 |
| V2 | Kite-like chart chrome: toolbar, Studies sheet, indicator chips and an indicator palette `ind1..ind4` + `indNeutral` with no green or red (contrast checked in both themes), RSI/MACD panes at 64 dp minimum, OHLC readout, 44 dp drawing handles, landscape full-screen (part 11) | FR-130 to FR-152 |
| V3 | Feedback styles under the one-snackbar rule: snackbar, banner, inline error, and which surface to use when (part 12); 5.13 is superseded by 12.2 | FR-156, FR-157 |
| V4 | App icon (3 SVG sources plus a monochrome layer), native splash spec (light/dark, no-flash rule, Android 12 and iOS) and the exact PNG size list (part 13) | FR-170 to FR-172 |
| V5 | One registry for images and icons with naming rules; every user-facing string through localisation (part 14) | FR-160 to FR-164 |
| V6 | New colour tokens for `SpColors`: `ind1..ind4`, `indNeutral`, `drawing`, `crosshair`, and `accentTint` (accent at 14%) | V1, V2 |

## Change log v1.4

| # | Change | Driven by |
|---|---|---|
| T1 | ATM chain row is **48 dp**, same as every row (was 52). Fixed row extent means a moving ATM causes no scroll drift (FR-23). ATM is marked by the `accent` 2 dp top/bottom rules, `surface2` strike cell and `ATM` caption label (5.4), drawn inside the 48 dp | dev-trading |

## Change log v1.3

| # | Change | Driven by |
|---|---|---|
| S1 | Disabled-Confirm reason now reads `Price not live since hh:mm:ss` (PRD FR-38 wording); the old `Prices not live for this contract` is gone. The feed-level banner keeps `Prices not live since hh:mm:ss` (plural, whole feed) | Design sign-off |

## Change log v1.2

| # | Change | Driven by |
|---|---|---|
| R1 | ATM position on open is **55%** of the viewport height (was 40%), matching FR-22; plus a `Back to ATM` button when ATM leaves the viewport | UX R1, PRD FR-22 |
| R2 | Banner copy is `Prices not live since hh:mm:ss`; the word "paused" is removed. Only the traded contract blocks orders (PRD 3.1, Q5), so a feed-level banner must not claim orders are paused | UX R2 |
| R3 | Confirm button reason line sits **above** the button everywhere (5.5 now agrees with 5.15) | UX R3 |
| R4 | `StaleBadge` shows the **as-of time** (`Stale since 10:42:07`), not an age counter (no 1 s ticking text; also drops the shared 1 s clock) | UX R4 |
| R5 | Chain row is **48 dp** (ATM row 52 dp in v1.2, now 48 dp, see v1.4) since every cell is a tap target; stacked layout height scales from 48 | UX R5 |

## Change log v1.1

| # | Change | Driven by |
|---|---|---|
| D1 | Order ticket: "Required margin" row removed; **Funds available** row added; "Margin not simulated" caption on short option sells (5.5) | PRD FR-39, PM |
| D2 | Navigation set to the UX 5 tabs: Watchlist, Options, AI, Portfolio, More; Orders lives under Portfolio; Socket Lab moves into More > Developer (7, 9) | PRD C13 |
| D3 | New states: Placing / checking status (5.5a), Pending order and unknown outcome (5.5b), Demo clock chip (5.8), quiet but live strike (5.7a) | PRD FR-14, FR-31a, FR-91, E16 |
| D4 | Stale threshold stated as age greater than 5.0 s (exactly 5.0 s is live); strikes are 41 (+/-20) | PRD 3.1, C3 |
| D5 | Component aliases for UX names added (5.15) | UX request |

Owner: ui-designer. Audience: dev lead, UX designer, QA. All data is simulated; the UI says so in Settings and the F&O notice, never in trading screens.
Contrast ratios below are computed WCAG 2.x relative-luminance ratios (not eyeballed). AA needs 4.5:1 for text under 18 sp, 3:1 for large text and graphics.

## 1. Design principles

1. **Numbers are the interface.** Price, change and P&L get the best type and the most room. Chrome (borders, icons, labels) stays quiet so a glance at 09:15 lands on the figure.
2. **Colour means direction, nothing else.** Green and red appear only for up/down and profit/loss. Buy is blue, Sell is red-tinted only on the Sell button (see 5.4). Warnings are amber, info is blue-grey. Never colour alone: every up/down carries a sign or arrow (NFR-12).
3. **Prices never perform.** No flashing, no sliding digits. v1 removed flash on purpose; v2 keeps a static direction colour. Calm beats lively when 50 rows tick at 4 Hz.
4. **Stale is louder than live.** A wrong price is the worst failure (R1). Stale state changes the row's look (dimmed number, amber badge) and disables trading; live state is the quiet default.
5. **Thumb first.** Primary actions live in the bottom 40% of the screen (the chain's ATM sits at 55%, which is scroll position, not action zone); targets are at least 48 dp; chain row to order sheet to confirm is 3 taps (G2).
6. **Dense but never clipped.** Compact rows at 1.0x text, rows grow (never truncate numbers) at 2.0x. Names ellipsize, numbers wrap to a new line or shrink padding, never clip.

## 2. Colour tokens

Seed colours are dropped (v1 used `colorSchemeSeed: 00B386`, which tints surfaces green and ties brand to "up"). v2 uses a neutral blue-grey base and an explicit `ColorScheme`.

### 2.1 Surfaces, text, accent

| Token | Dark | Light | Use |
|---|---|---|---|
| `surface0` (page) | `#0E1116` | `#FFFFFF` | Scaffold |
| `surface1` (card, row on hover) | `#171C24` | `#F3F5F8` | Cards, sheets, chain header |
| `surface2` (raised, input) | `#202733` | `#E8ECF2` | Inputs, segmented track, chips |
| `outline` | `#2C3544` | `#D5DBE4` | Dividers (1 dp hairline) |
| `textPrimary` | `#E8ECF2` (15.95:1) | `#12161C` (18.15:1) | Prices, symbols |
| `textSecondary` | `#A3ADBB` (8.33:1; 7.53 on surface1) | `#4A5565` (7.56:1) | Names, labels |
| `textTertiary` | `#7F8A99` (5.40:1) | `#667085` (4.55:1 on surface1) | Timestamps, hints. Never for numbers |
| `accent` | `#5AA9FF` (7.70:1) | `#0B5CAD` (6.67:1) | Links, selected tab, focus ring, Buy |
| `onAccent` | `#06121F` (7.68:1 on accent) | `#FFFFFF` (6.67:1) | Text on filled accent |

### 2.2 Market and status

| Token | Dark | Light | Contrast on surface0 / surface1 |
|---|---|---|---|
| `up` | `#3DDC97` | `#00704F` | dark 10.70 / 9.68; light 6.12 / 5.60 |
| `down` | `#FF7A6B` | `#C42B1C` | dark 7.43 / 6.72; light 5.66 / 5.18 |
| `warn` (stale, nudges) | `#F2B84B` | `#8A5A00` | dark 10.57; light 5.93 |
| `info` | `#6CB4FF` | `#0B5CAD` | dark 8.65; light 6.67 |
| `upTint` / `downTint` / `warnTint` / `infoTint` | token at 14% alpha over surface | same | Chip and bar backgrounds only, never behind text smaller than the token passes on |
| `buy` / `sell` | = `accent` / `down` | = `accent` / `down` | Sell button label: white on `#C42B1C` 5.66; dark `#1A0A08` on `#FF7A6B` 7.56 |

All up/down text passes AA (4.5:1) on both surfaces in both themes. Every pair is above 5:1, so no large-text exemption is used.

### 2.3 Rules for when colour is allowed

- **Allowed on `up`/`down`:** change value, change %, P&L, day P&L, chain LTP change, payoff above/below zero, OI change sign, sparkline stroke.
- **Not allowed:** buttons other than Sell, headings, icons that are not direction arrows, selected states, charts of non-directional data (OI bars use `info`/`textTertiary`, see 5.4).
- **Price LTP text** stays `textPrimary`. Direction shows through the change chip and, optionally, the static last-tick colour (`TickPrice`) which resets to primary 1.5 s after the last change (no animation, computed from the tick timestamp on rebuild, no per-row timer).
- **Zero change** is `textSecondary` with no sign.
- **Colour-blind safety:** up shows `▲`/`+`, down `▼`/`-` always. Test with deuteranopia simulation; the sign carries meaning.
- **v1 failure:** `00B386` on white is 2.69:1 and `EB5B3C` on white 3.45:1. Both fail AA in light theme. Light theme tokens above fix this.

## 3. Typography

Font: platform default (Roboto on Android, SF on iOS) via Material 3 `TextTheme`; no bundled font, to protect startup (NFR-2). If a font is added later, use Inter, which has tabular figures.

**Every number uses tabular figures**: `FontFeature.tabularFigures()` baked into every numeric style (`SpTypography`), not added per call (v1 adds it ad hoc in two places). Right-align numeric columns. Use the Indian grouping format (`₹1,23,456.75`) from `Fmt`.

| Style | M3 base | Size / line / weight | Used for |
|---|---|---|---|
| `priceLarge` | headlineMedium | 28 / 34 / w600 | Stock page LTP, order sheet total |
| `price` | titleMedium | 16 / 22 / w600 | Watchlist LTP, positions LTP |
| `priceDense` | bodyMedium | 14 / 18 / w500 | Chain LTP, strike, table cells |
| `change` | bodySmall | 12 / 16 / w500 | Change and % in rows, chain OI change |
| `changeLarge` | titleSmall | 14 / 20 / w600 | Stock page change line |
| `symbol` | titleSmall | 14 / 20 / w600 | Symbol in rows |
| `label` | labelMedium | 12 / 16 / w500 | Section labels, badges, chips |
| `caption` | labelSmall | 11 / 14 / w500 | Timestamps, "as of", never for key numbers |
| `body` | bodyMedium | 14 / 20 / w400 | AI text, notices |
| `title` | titleLarge | 20 / 28 / w600 | App bar, sheet titles |
| `button` | labelLarge | 14 / 20 / w600 | Buttons |

Minimum text size is 11 sp (caption), used only for non-critical metadata.

### Behaviour at 200% text scale (NFR-12)

- Do not clamp the scale globally. Clamp at most to 1.6x on the three densest widgets (`ChainRow` numeric cells, tab labels, `StaleBadge`) via `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.6)`, and make up for it with layout (below).
- `QuoteRow`: height is `max(56, content)`; at 2.0x the secondary line (exchange and name) wraps to 2 lines and the change line moves under the price. Price never ellipsizes; use `FittedBox` with `scaleDown` only as the last resort.
- `ChainRow`: at scale above 1.3 switch to a **stacked layout**: strike header line, then CE and PE cells below as two columns (LTP over OI). Row height 48 dp becomes about 96 dp. Horizontal scroll is not used.
- Segmented controls wrap to two lines or become a vertical list when the labels do not fit in one line at the current scale.
- All tap targets use `ConstrainedBox(minHeight: 48)`, which also scales.
- Golden tests at 1.0 and 2.0 for QuoteRow, ChainRow, OrderTicket, StaleBadge.

## 4. Spacing, radius, elevation, density

| Token | Value | Notes |
|---|---|---|
| `space1…8` | 4, 8, 12, 16, 20, 24, 32, 48 | 4 dp base grid |
| Screen gutter | 16 dp (12 dp in chain) | |
| `radiusS / M / L / pill` | 6 / 10 / 16 / 999 | S chips and cells, M cards and inputs, L sheets (top corners), pill badges |
| Elevation | none on rows and cards; 1 dp outline instead of shadow | Dark theme shadows are invisible; hairlines work in both |
| Sheets and dialogs | surface1 plus M3 tonal overlay, scrim 50% black | Only the bottom sheet and the snackbar float |
| Row height, watchlist | **56 dp** min (two lines: symbol/name, price/change) | v1 ListTile is 72 dp, so about 30% more rows on screen |
| Row height, chain | **48 dp** min | Every cell is a tap target, so visual height equals hit height; 41 strikes scroll anyway (ATM row is also 48 dp: fixed `itemExtent`, so ATM moving never shifts the scroll offset, FR-23) |
| Row height, positions / orders | 64 dp | Three lines: contract, qty, P&L |
| Tap target | 48 x 48 dp min | Chain cells are 48 high, no padding trick needed |
| Section header | 32 dp | |

`VisualDensity.compact` is allowed only on chips and the connection badge; never on rows, buttons or segmented controls.

## 5. Component specs

Names are prefixed `Sp` in code (e.g. `SpPriceCell`) except where noted. All live in `lib/core/widgets/` or the owning feature's `presentation/widgets/`.

### 5.1 Price cell (`PriceCell`, replaces `TickPrice`)
- **Anatomy:** one `Text`, tabular `price` / `priceDense` style, right-aligned, `₹` prefix optional.
- **States:** live (textPrimary); last tick up/down (static `up`/`down` colour until 1.5 s after the last change); stale (textTertiary plus strikethrough off, with `StaleBadge` nearby); loading (`—`); closed (textPrimary, "as of" in caption).
- **Flutter:** `StatelessWidget` taking value, text, `lastDirection`, `isStale`. Wrap in `RepaintBoundary` when used in chain cells. `Semantics(label: 'Price 2,450.50 rupees, up')`. `ExcludeSemantics` on the inner text.

### 5.2 Change chip (`ChangeChip`)
- **Anatomy:** arrow glyph `▲ ▼ –`, signed change, percent in parentheses: `▲ +12.40 (+0.51%)`. In rows it is text only (no background); on the stock page it has `upTint`/`downTint` background, `radiusS`, 8 x 4 dp padding.
- **States:** up, down, flat (textSecondary), unavailable (`—`).
- **Flutter:** one widget with a `compact` flag. Text colour is the token from `SpColors.directionOf(change)`. Semantics: "Up 12.40 rupees, 0.51 percent".

### 5.3 Quote row (`QuoteRow`, evolves `QuoteTile`)
- **Anatomy:** `[symbol / exchange · name]` left; `[PriceCell / ChangeChip]` right; optional `StaleBadge` replaces the name line when stale; 1 dp bottom hairline (inset 16 dp).
- **States:** normal, pressed (surface1), selected (accent 3dp left bar), stale (price dimmed, badge), no quote (`—`), reorder-drag (surface2, radiusM).
- **Flutter:** keep v1's per-row `select` to repaint one row. Replace `ListTile` with a `InkWell` plus `Row` for exact 56 dp. Long-press opens the action sheet (FR-4). Row-level `Semantics(label: 'Reliance, 2,450.50, up 0.51 percent')`, `mergeSemantics`.

### 5.4 Option chain row (`ChainRow`: CE | strike | PE)
- **Anatomy (1.0x):** `[OiBar + CE OI chg | CE LTP] [strike] [PE LTP | OiBar + PE OI chg]`, columns 36% / 28% / 36%. CE grows from the strike outwards to the left, PE to the right (bars point away from the centre), matching Kite and Sensibull.
- **ATM marker:** the strike cell is `surface2` with `accent` 2 dp top and bottom rules and a small `ATM` label in `caption`; chain is scrolled so ATM is centred at 55% of the viewport height on open and on expiry change (FR-22), with a `Back to ATM` button once ATM leaves the viewport. ITM side has `surface1` tint; OTM stays `surface0` (the standard ITM shading).
- **OI bar:** height 6 dp inside the cell, width is OI divided by max OI on screen. CE bar `info`, PE bar `textTertiary`: two neutral hues, so no green/red is implied. Bars are static; a width change is applied without animation.
- **States:** normal, ATM, ITM tint, selected cell (accent outline 2 dp), stale (cells dimmed), no data (`—`), expired (`Expired` badge, cells disabled).
- **Flutter:** each cell is a `ConsumerWidget` selecting its own contract (NFR-5); `RepaintBoundary` per row; bars are `CustomPaint` (one `drawRect`) or `FractionallySizedBox`. Tap a cell opens the Buy/Sell sheet (FR-26); long-press strike opens greeks (FR-27). Semantics: "Strike 24,500, call 112.30, open interest 1.2 million, add 3 percent".

### 5.5 Order ticket (`OrderTicket`) and Buy/Sell colour
**Decision: Buy is blue (`accent`), Sell is red (`down` family).** Reasons: (1) green and red already mean up and down, and a green Buy next to a red falling price causes mis-taps ("Buy because green" after a drop). (2) Zerodha Kite uses blue Buy / orange-red Sell and has the largest Indian retail base, so it matches the user's mental model (see brief). (3) Sell in red does not carry a direction claim: it is an action, and red is the standard "risk" cue for a sell/short. (4) Blue passes AA with white text in light (6.67) and dark text in dark (7.68). A side-effect is that the sell button and a falling price share a hue; accepted, because the button is labelled and filled while the price is text.
- **Anatomy (top to bottom):** drag handle; header `[Buy|Sell toggle]` plus contract name and live LTP (`PriceCell`) with `StaleBadge`; `SegmentedChoice` product (MIS/CNC or MIS/NRML); `SegmentedChoice` order type (Market/Limit/SL); `LotStepper` (48 dp +/-, lots for F&O) with `units = lots x lot size`; price (and trigger) fields; summary rows (**Funds available**, Order value in ₹, Max loss for F&O buys). Margin is not simulated, so there is no margin row; short option sells show a `caption` line in `textSecondary` under the summary: `Margin not simulated`; soft nudge strip (`warnTint`); full-width confirm button, 52 dp, in the thumb zone.
- **Confirm button text:** `Buy 2 lots NIFTY 24500 CE` (side-coloured). Disabled state shows the reason on a line **above** the button in `warn` text ("Price not live since 10:42:07", the PRD FR-38 wording with the contract's as-of time), so the thumb never covers it.
- **States:** idle, editing, validation error (inline, `down` text with an icon, field outline 2 dp), nudge, stale (disabled), submitting (button shows spinner, inputs locked, double-tap ignored, FR-31), rejected (inline banner, rejection haptic), market closed (disabled with reason).
- **5.5a Placing / checking status (FR-31a):** the confirm button becomes a locked `BlockedConfirmButton` variant: spinner (20 dp) plus label `Placing...`; after 3 s without an answer the label changes to `Checking status...` (text swap, no animation). The button keeps the full side colour (no 60% fade, so label contrast stays at least 4.5:1); the spinner and locked inputs show the state. Inputs locked, sheet cannot be swiped away, back is ignored, `Semantics(liveRegion: true)` announces `Placing order` then `Checking order status`. Double taps are ignored.
- **5.5b Pending / unknown outcome:** if retries fail the sheet closes and `SpSnack` says `Order status unknown. See Orders` (6 s, `View` action). In Portfolio > Orders the row shows a `PendingBadge` (same pill shape as `StaleBadge`, `info` text on `infoTint`, hourglass icon, text `Pending`), never `down` or `warn`, because Pending is not a failure and not a price warning. The row stays until resync gives the final state, then it swaps to Filled/Rejected with one notice and one haptic. Never offer a Retry button on a Pending row (no auto or manual resubmit); the only action is `Refresh status`.
- **Flutter:** `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)`, `DraggableScrollableSheet` not needed; content in `SingleChildScrollView` with `viewInsets.bottom` padding; confirm button pinned outside the scroll area so it never hides under the keyboard.

### 5.6 Segmented controls (`SegmentedChoice`)
> v2.0: this is the inline variant of `SpPicker` (see [10 SpPicker](03b-design-system/10-sp-picker.md)); use it for 2 to 4 short options, the sheet variant otherwise.

- **Anatomy:** track `surface2` radiusM, 40 dp high (48 hit area), selected segment `surface0` (light) / `surface1` (dark) with `accent` text and 1 dp accent outline. Selected state also uses a check glyph or weight w700, so selection is not colour-only.
- **States:** default, selected, disabled (textTertiary, e.g. CNC for F&O is hidden, not disabled), pressed.
- **Flutter:** wrap M3 `SegmentedButton<T>` with a themed `SegmentedButtonThemeData`; use `showSelectedIcon: false` and `style` from the theme. Product choice for F&O offers only MIS / NRML (FR-32).

### 5.7 Stale badge (`StaleBadge`)
- **Anatomy:** pill, `warnTint` background, `warn` text and a clock icon: `⏱ Stale since 10:42:07`. Shows the as-of time (tabular, device-local), not a running age, so it does not repaint every second; 11 sp caption minimum, text is `warn` (5.93 light, 10.57 dark).
- **States:** stale-instrument (inline in row), stale-feed (banner under app bar, full width, 36 dp: "Prices not live since 10:42:07"; no claim about orders, because only the traded contract blocks confirm), recovering (fades to nothing on the next tick, no animation).
- **Flutter:** a `ConsumerWidget` that shows the fixed `asOf` time and flips to stale from the existing server-adjusted clock check; no per-second repaint and no timer per row. `Semantics(liveRegion: true)` on the banner only.

### 5.7a Quiet but live strike
A deep OTM strike with no trade for 60 s is **live** while the keep-alive confirms it every 2 s or less (FR-91). It must look identical to any live cell: no dimming, no `StaleBadge`, no `textTertiary`. Do not show `last traded` age on cells. Only `asOf` age greater than 5.0 s (exactly 5.0 s is live) triggers the stale look. A quiet strike shows an unchanged price and a `0` or `-` OI change in `textSecondary`; zero volume is a data fact, not a status. Semantics do not mention staleness. QA golden: a cell with tick age 60 s and `asOf` age 1 s renders as live.

### 5.8 Market status pill (`MarketStatusPill`)
- **Anatomy:** pill with dot and label: `● Open`, `● Pre-open`, `● Closed · as of 15:30:00`. Dot colour is **not green**, to avoid direction meaning: open = `accent` filled dot, pre-open = `warn`, closed = `textTertiary` hollow dot. Text always spelled out (colour never alone).
- **Flutter:** `Chip`-like `Container`, 28 dp high, `label` style.
- **Demo clock chip (FR-14, FR-116, E16):** demo mode is the default, so the chip is visible in dev and profile builds whenever the virtual clock is on. It is a second pill next to the phase pill: `info` text on `infoTint`, clock icon, text `Demo clock 10:00` (virtual time, tabular). Always visible (never auto-hides), tap opens the debug clock sheet. It is never green or red and never replaces the phase pill, so the user sees both `Open` and `Demo clock`. Under 1.3x text scale the two pills stack in the app bar bottom row. Semantics: `Demo clock, virtual time 10:00, market open`.

### 5.9 Connection badge (`ConnectionBadge`)
- **Anatomy:** 8 dp dot and label (`Live 23 ms`, `Reconnecting 2s`, `Offline`, `Paused`), no chip border, in the app bar.
- **Colour:** live = `textSecondary` text with `accent` dot; reconnecting = `warn`; paused = `textTertiary`; offline = `warn` with an icon (red is reserved for price direction). Replaces v1's `Colors.green/orange/grey/amber` (hard-coded, five hues, and green clashes with up).
- **Flutter:** keep provider logic; swap colours for `SpColors`; drop `Chip` (its 32 dp+ height and padding are heavy in an app bar). Semantics label spells out the state.

### 5.10 AI answer card shell (`AiCardShell`)
- **Anatomy:** `surface1` card, radiusM, 12 dp padding, 1 dp outline; header row (small icon, card type label such as `NIFTY chain`, `as of 10:42:07` caption); body slot (text, quote, table, chart, payoff); footer with action buttons (`TextButton`s: Open chain, Trade this strike, Set alert, View payoff). A permanent footer line in caption: `Simulated. Not advice.`
- **States:** streaming (skeleton line and a 2 dp progress rule at the top, no shimmer), complete, stale-embedded-price (inline `StaleBadge`), error (`ErrorView` inline, retry), off-screen (live parts pause).
- **Flutter:** one shell with a `child` slot; each card type supplies the body. User bubbles are `accent` filled; AI cards are never green or red-tinted.

### 5.11 Payoff chart (`PayoffChart`)
- **Styling:** `CustomPainter`, one line for expiry payoff (2 dp stroke, `textPrimary`), dashed line for "today" (`info`), zero line (1 dp `outline`), fills: above zero `upTint`, below zero `downTint`. Breakeven points get a dot and label; current spot gets a vertical `accent` line. Axis labels `caption`, 4 to 5 ticks maximum.
- **Crosshair (FR-73):** drag shows a tooltip card at the top (spot and P&L, `price` style) with the crosshair line; haptic `selectionClick` on each breakeven crossing only.
- **Max profit / max loss** shown as chips under the chart with explicit text ("Max loss ₹8,450"), so the picture is never the only source of risk.
- **Flutter:** `RepaintBoundary`, repaint only on crosshair or leg change; semantics summary: "Payoff at expiry. Max loss 8,450. Breakeven 24,612".

### 5.12 Bottom sheet (`SpSheet`)
- Top corners `radiusL`, surface1, drag handle 32 x 4 dp `outline`; max height 90% of the screen; scrim 50%. Dismiss by drag or back. Sheets that hold unsaved order inputs ask nothing on dismiss (inputs are kept per E5). `showModalBottomSheet` with `useSafeArea`, `showDragHandle: true`.

### 5.13 Snackbar (`SpSnack`)
> v2.0: superseded and extended by [12 Feedback](03b-design-system/12-feedback.md); one snackbar at a time (FR-156).

- Floating, radiusM, `inverseSurface`; max 2 lines; 4 s (6 s with an action). Fill notices: "Filled: Bought 65 NIFTY 24500 CE at 112.30" with a `View` action. Rejections persist until dismissed. Never covers the order confirm button: sheet-hosted messages use the inline banner instead. Announce with `SemanticsService.announce`.

### 5.15 Name aliases for the UX spec
| UX name | Design system name |
|---|---|
| PriceText | `PriceCell` plus `ChangeChip` (arrow, signed change, live/stale/closed variants) |
| StaleBanner | `StaleBadge` banner variant (5.7) |
| MarketStatusChip | `MarketStatusPill` plus the Demo clock chip (5.8) |
| BlockedConfirmButton | Confirm button disabled state with reason line **above** it (`warn` text); also hosts the Placing / Checking states (5.5a) |
| NudgeCard | `warnTint` strip, dismissible, in the sheet; soft only, never blocks |
| LotStepper | 48 dp +/- buttons around a tabular value; long-press repeats |
| AiCard | `AiCardShell` |

### 5.14 Empty and error views (`EmptyView`, `ErrorView`)
- **Anatomy:** 48 dp outline icon (`textTertiary`), title (`title`), one-line reason (`body`, textSecondary), one primary action. Centered, max width 320.
- **Copy:** says what happened and what to do ("Watchlist is empty. Add a stock"). Dev hints (v1's "cd market_server && dart run...") move to Socket Lab or debug builds only.
- **Offline-with-cache:** not an error view; show cached rows with the stale banner.
- **Flutter:** `EmptyView({icon, title, message, actionLabel, onAction})`; `ErrorView` keeps `message` and `onRetry`.

## 6. Motion

| Item | Animates? | Duration / curve |
|---|---|---|
| Prices, change %, OI bars, chain cells | **Never** | Value swaps instantly; static direction colour only |
| Sheet open/close | Yes | 250 ms / 200 ms, `easeOutCubic` / `easeInCubic` (M3 defaults) |
| Page transitions | Yes | 250 ms platform default |
| Segmented selection | Yes | 150 ms fade of the selected background |
| Button pressed | Yes | Ink ripple, M3 default |
| Snackbar | Yes | 200 ms in, 150 ms out |
| Chain scroll to ATM on open | Instant jump (no animated scroll) | 0 ms. Animated scroll over 20 rows wastes frames |
| Chart crosshair | Follows the finger, no easing | 0 ms |
| Skeleton / loading | No shimmer; static placeholder with a single `CircularProgressIndicator` for actions | |
| Reduce motion | `MediaQuery.disableAnimations` makes all of the above 0 ms | |

Rule: if an element updates more than once a second, it does not animate.

## 7. Iconography and haptics

- **Icons:** Material Symbols Rounded outline, 24 dp (20 dp in dense rows), `textSecondary`. One weight (400). Filled only for the selected nav item. Direction arrows are the text glyphs `▲ ▼` so they follow the font scale; no icon-only buttons without a tooltip and semantics label.
- **Nav (matches the UX spec):** Watchlist, Options, AI, Portfolio, More (5 items). Orders is a segment inside Portfolio; Settings, Alerts management and Developer (Socket Lab, debug clock) live in More. Labels always visible (`NavigationBarDestinationLabelBehavior.alwaysShow`). Selected item: filled icon plus `accent` indicator, not colour alone. Tabs build lazily (FR-82).
- **Haptics (platform channel, FR-100):**

| Event | Pattern | Notes |
|---|---|---|
| Order filled | `success` (medium impact then light, 80 ms apart) | Once per fill, deduped by order id |
| Order rejected | `error` (two heavy, 120 ms apart) | Distinct from success |
| Segment/Buy-Sell toggle, stepper | `selectionClick` via `HapticFeedback` (built-in) | No channel needed |
| Chart breakeven crossing | `selectionClick` | |
| Price ticks, alerts firing | none (alerts use the notification channel) | Haptics on ticks would buzz continuously |

Haptic toggle in Settings (FR-102); macOS/web is a silent no-op (FR-101). Every haptic has a visible equivalent (snackbar or banner).

## 8. Token to Flutter mapping

No code generation. Hand-written classes in `lib/core/theme/`.

| Token(s) | Flutter target |
|---|---|
| `surface0` | `ColorScheme.surface`, `ThemeData.scaffoldBackgroundColor` |
| `surface1`, `surface2` | `ColorScheme.surfaceContainerLow`, `surfaceContainerHigh`; also `SpColors.surface1/2` |
| `outline` | `ColorScheme.outlineVariant`, `DividerThemeData.color` |
| `textPrimary` / `textSecondary` | `ColorScheme.onSurface` / `onSurfaceVariant` |
| `textTertiary` | `SpColors.textTertiary` (ThemeExtension) |
| `accent`, `onAccent` | `ColorScheme.primary`, `onPrimary` |
| `up`, `down`, `warn`, `info` | `SpColors` ThemeExtension (`ColorScheme.error` = `down`) |
| `upTint`, `downTint`, `warnTint` | `SpColors` getters (alpha over surface) |
| `buy`, `sell` | `SpColors.buy`, `SpColors.sell` |
| Typography table | `SpTypography` ThemeExtension (`price`, `priceDense`, `change`, ...) plus M3 `TextTheme` for the rest |
| Spacing, radius | `abstract final class SpSpace`, `SpRadius` (const doubles) |
| Row heights | `abstract final class SpDensity` (`watchlistRow = 56`, `chainRow = 48`, `tap = 48`) |
| Segmented | `SegmentedButtonThemeData` |
| Sheet | `BottomSheetThemeData` (shape, showDragHandle, backgroundColor) |
| Snackbar | `SnackBarThemeData` (floating, shape) |
| Nav | `NavigationBarThemeData` (indicator, label behaviour) |
| Inputs | `InputDecorationTheme` (filled, surface2, radiusM) |
| Ripple, focus | `ThemeData.focusColor` = accent at 24% |
| Dark/light | `AppTheme.dark()` / `AppTheme.light()`; `themeMode: ThemeMode.system` with a Settings override (v1 forces dark) |

`SpColors` implements `copyWith` and `lerp`; access via `context.sp` (an extension on `BuildContext` returning `Theme.of(this).extension<SpColors>()!`). Widgets must not use `Colors.*`; a lint-style grep check in CI: `grep -rn "Colors\\." lib/` returns nothing outside the theme folder.

## 9. Review notes on v1's look

1. **Light-theme up/down fail AA.** `00B386` is 2.69:1 and `EB5B3C` 3.45:1 on white. *Fix:* separate light tokens `00704F` (6.12) and `C42B1C` (5.66); use `SpColors`, not static `MarketColors`.
2. **Theme forced dark, seeded green.** `colorSchemeSeed: 00B386` tints surfaces, nav and buttons green, so brand and "up" mean the same thing, and `Colors.green` in `ConnectionBadge` adds a second "green". *Fix:* neutral blue-grey base, accent blue, green only for up; follow system theme.
3. **Rows are `ListTile`s (72 dp) with the price in `trailing`.** Few rows per screen; the name line steals width from the figures; no semantics grouping. *Fix:* 56 dp `QuoteRow`, symbol and name left, price and change right, merged semantics.
4. **Tabular figures added ad hoc** (two call sites) and the LTP switches colour on each downtick without any reset, so a stale red price looks like a live fall. *Fix:* tabular figures in every numeric style; direction colour decays to primary after 1.5 s; stale dims.
5. **Connection badge is a full `Chip`** with five hard-coded hues, a "Retry #3 in 2.0s" label that is jargon for Rohan, and no semantics. *Fix:* quiet dot plus text, plain labels ("Reconnecting", "Offline"), warn rather than red.
6. **Error view leaks dev instructions** ("cd market_server && dart run ...") to every user and offers one button with no variant for empty or offline-with-cache. *Fix:* split `EmptyView` / `ErrorView`, move the hint to debug builds, show cached data with a stale banner instead of an error whenever a cache exists.
7. **Navigation exposes "Socket Lab" as a peer of Watchlist and Portfolio.** *Fix:* move it into More > Developer; the five slots become Watchlist, Options, AI, Portfolio, More.
