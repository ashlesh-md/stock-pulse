# 03 · UX spec part 11: Designed picker `SpPicker` (v2.0)

Owner: ux-designer · Part of `../03-ux-spec.md` v2.0 · PRD FR-155 (CR-1.0b) · Visuals: 03b (ui-designer)

`SpPicker` replaces every `DropdownButton`, `DropdownMenu` and choice `PopupMenuButton`. One component, two
presentations, chosen by the rules below, so screens never pick a look themselves.

## 11.1 Which presentation

| Use **inline segmented** (`SegmentedChoice`) when all are true | Use **bottom-sheet list** when any is true |
|---|---|
| 2–4 options | 5 or more options, or the list can grow (expiries) |
| Short labels (≤ 8 characters at 1.0×) | Options need a description, glyph or disabled reason |
| All options fit in one row at the current text scale | Multi-select |
| The choice changes often inside one task (side, type) | The choice is occasional (interval, chart type) |

**Automatic fallback:** a segmented picker that does not fit in one row (text scale, pseudo-locale +40 %, narrow
width) renders as a sheet-list trigger instead. Same value, same semantics; the screen code does not change.

## 11.2 Where pickers appear

| Place | Options | Presentation | Default | Notes |
|---|---|---|---|---|
| Ticket: side | Buy · Sell | Segmented | From caller | Buy blue, Sell red when selected |
| Ticket: product | CNC · MIS (equity), NRML · MIS (F&O) | Segmented | CNC / NRML (FR-32) | CNC hidden for F&O |
| Ticket: order type | Market · Limit · SL | Segmented | Market (Limit from chart/link price) | Pre-open equity: Market disabled with caption (§3.4) |
| Alert: direction | Above ≥ · Below ≤ | Segmented | From LTP side | |
| Portfolio sub-tabs | Positions · Holdings · Orders | Segmented (tab style) | Positions | Counts in labels |
| Chart: range | 1D 1W 1M 3M 6M 1Y 5Y | Chips row (portrait), sheet list (landscape rail) | Remembered (FR-147) | 7 options, chips scroll |
| Chart: interval | 1m 5m 15m 1h 1d 1w | Sheet list | Remembered | Invalid for range: disabled + "Not for 5Y" |
| Chart: type | Candles, Heikin-Ashi, OHLC bars, Line, Area, Hollow candles (C) | Sheet list with glyphs | Remembered | |
| Chart: study parameters | Period presets (+ stepper), colour | Segmented presets + stepper | Study default | In the study settings sheet |
| Chain: expiry | Up to 8 expiries | Chips row in header; sheet list from the bottom `Expiry ▾` chip | Nearest (FR-29b) | Today's expiry captioned "Expires today"; expired = disabled |
| Chain: underlying | NIFTY, RELIANCE, HDFCBANK | Sheet list | Last viewed; none selected on first run | Shows LTP per row (live) |
| Chain: columns | OI, ΔOI, LTP, IV, Δ | Sheet list, **multi-select** with `Done` | OI, ΔOI, LTP | LTP cannot be unticked (caption "Always shown") |
| Studies list | Part 10 §10.4 | Sheet list with sections | — | Uses `SpPicker` rows with trailing `+` |
| Debug clock presets | 4 presets | Sheet list | — | Debug only |

## 11.3 Trigger (closed state)

```
 [ 5m ▾ ]        chip trigger: value + chevron, 48dp tall, min 64dp wide
 Interval  5 min ▾   labelled trigger in forms (label above at > 1.3x)
```

- Shows the **current value**, never a placeholder like "Select". Disabled trigger shows the value dimmed plus a
  reason caption below (e.g. "Needs connection").
- A value that is loading (chart interval) shows a 16 dp spinner in place of the chevron (part 10 §10.1).

## 11.4 Sheet list (open state)

```
┌────────────────────────────────────────┐
│ ── Interval                            │ title = what is being chosen
│ 1 minute                               │ 48dp rows (56dp with caption)
│ 5 minutes                            ✓ │ selected: tick + semibold
│ 15 minutes                             │
│ 1 hour                                 │
│ 1 day                                  │
│ 1 week                     Not for 1D  │ disabled + reason, still readable
└────────────────────────────────────────┘
```

- `SpSheet`, drag handle, height fits content up to 60 % of the screen, then scrolls; the selected row is scrolled
  into view on open.
- **Single-select:** tapping a row selects it, gives a light selection haptic, and closes the sheet (no OK button).
  Tapping the already selected row just closes.
- **Multi-select:** rows have checkboxes; a pinned `Done` (48 dp, bottom, thumb zone) applies; drag-down or back
  discards changes.
- Long lists (expiry) keep order by date; no search box (no list is longer than 8 items in v2).
- Disabled options stay in the list with a reason (so the trader learns why), never removed silently.
- Row content: label, optional caption (second line), optional leading glyph (chart type), optional trailing live
  value (underlying LTP, which follows the stale rule).

## 11.5 Segmented (inline)

- Each segment ≥ 48 dp tall and ≥ 64 dp wide; selected = filled, others outlined; selected segment carries a tick
  for non-colour cue (03b 5.6).
- Change is immediate; no confirmation. A segment that is not allowed now (Market in pre-open) is disabled with a
  caption under the control, and tapping it focuses the caption (no snackbar).

## 11.6 Keyboard and accessibility

| Topic | Rule |
|---|---|
| Trigger semantics | Button: "Interval, 5 minutes. Double-tap to change." Disabled adds the reason |
| Sheet semantics | Title is a heading; rows are a radio group (single) or checkboxes (multi); selected says "selected"; disabled says "unavailable, not for 1 day" |
| Segmented semantics | Radio group with the label ("Order type"), each segment "Limit, 2 of 3, selected" |
| Focus | Opening moves focus to the selected row; closing returns focus to the trigger |
| Hardware keyboard | Enter/Space opens; ↑/↓ move; Enter/Space selects; Esc closes without change; Tab is trapped inside the sheet; ←/→ move between segments |
| Text scale 2.0 | Rows grow (labels wrap to 2 lines, no truncation); segmented falls back to the sheet trigger (§11.1) |
| Targets | All rows and segments ≥ 48 dp (FR-155 `androidTapTargetGuideline`) |
| Reduced motion | Sheet opens without slide |

## 11.7 Components needed from ui-designer

`SpPicker` trigger (chip and labelled variants, loading and disabled states), sheet-list row (label, caption,
glyph, trailing value, tick, checkbox, disabled), segmented control (2–4 segments with tick), multi-select `Done`
bar. Goldens for light, dark, 1.0× and 2.0×.
