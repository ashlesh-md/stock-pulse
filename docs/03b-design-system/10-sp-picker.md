# 03b Part 10: SpPicker (v2.0)

Replaces every `DropdownButton`, `DropdownMenu` and choice `PopupMenuButton` (PRD FR-155): chart type, interval, study parameters, order type, product, chain columns, alert direction. Owner: ui-designer. Consumer: dev-trading.

## 10.1 Decision

Flutter's default dropdown draws an anchored Material menu that ignores our surfaces, clips on 360 dp screens, has a 48 dp-short tap target in dense rows and gives no search or description. `SpPicker` has **two variants behind one API**; the call site passes options and the component chooses by count and context.

| Variant | Use when | Why |
|---|---|---|
| **Inline segmented** (`SpPicker.segmented`) | 2 to 4 options, every label 12 characters or fewer, all visible at once (MIS / NRML, Market / Limit, Above / Below) | One tap, no sheet, state always visible. This is the existing `SegmentedChoice` (5.6) |
| **Bottom-sheet list** (`SpPicker.sheet`) | 5 or more options, long labels, options with a description or a number (chart type, interval, expiry, chain columns), or a field inside a row that has no room for chips | Thumb zone, big targets, scrolls, can hold a check mark and a hint |

Rule: more than 4 options, or any option with a second line, always uses the sheet. A field that has few options but sits in a toolbar uses the sheet's closed trigger (a compact field), not chips.

## 10.2 Anatomy

**Trigger (closed field, sheet variant)**
- Height 48 dp (40 dp visual, 48 dp hit area) in forms; **36 dp visual / 48 dp hit** `compact` in the chart toolbar.
- `surface2` fill, radius `m` (10), 1 dp `outline`. Left: optional 20 dp icon (`textSecondary`). Body: label caption above value is **not** used in toolbars; forms show a 12 sp `label` above the field. Value: `body`, `textPrimary`, one line, ellipsis. Right: 20 dp chevron-down (`textSecondary`).
- Numeric values use tabular figures (`price` style) so `5m` and `15m` align.

**Sheet (`SpSheet`, 5.12)**
- Drag handle, title (`title`, the field name), optional search field when options exceed 12, list of rows.
- **Row:** 52 dp (48 dp minimum at 200% text, grows with text). Leading optional icon 24 dp, label `body` `textPrimary`, optional second line `caption` `textSecondary`, trailing check (20 dp, `accent`) on the selected row. Selected row also has w600 label and `accentTint` (accent at 14%) fill, so selection is never colour alone. Dividers are hairline `outline`, inset 16 dp.
- Max height 70% of the screen; scrolls inside. Sheet closes on selection (single select) after 120 ms so the check is seen; multi-select (chain columns) has a pinned `Done` button instead.
- Disabled option: `textTertiary` label, no check, reason in the second line (`Needs a 1d interval`). Not hidden unless it is impossible (CNC for F&O is hidden, FR-32).

**Segmented variant**
- Track `surface2`, radius `m`, 40 dp visual, 48 dp hit. Selected segment as 5.6. Equal widths; if labels do not fit at the current text scale the component falls back to the sheet variant automatically (no clipped text).

## 10.3 States

| State | Trigger | Sheet row | Notes |
|---|---|---|---|
| default | `surface2`, `outline` | | |
| pressed | ink ripple, `surface1` overlay at 8% | row overlay 8% | |
| focused (keyboard, switch access) | 2 dp `accent` ring, offset 2 dp | same ring on the row | 3:1 against any neighbour: accent 7.70 on dark surface0, 6.67 on light |
| open | trigger outline becomes 2 dp `accent`, chevron up | | |
| selected | value shown | check plus `accentTint` plus w600 | |
| disabled | `textTertiary` text, outline 50%, no ripple, reason as helper text below | greyed with reason line | Never disabled without a reason line |
| error | 2 dp `down` outline plus icon plus helper text in `down` (colour plus icon plus words) | | e.g. `Pick an expiry` |
| loading options | trigger shows value, sheet shows a 20 dp `CircularProgressIndicator` and `Loading...` | | no shimmer |
| empty search | `EmptyView` small: `No match for "xyz"` | | |

## 10.4 Sizes

| Size | Trigger visual height | Hit area | Where |
|---|---|---|---|
| `regular` | 40 dp | 48 dp | Forms, order ticket, settings |
| `compact` | 36 dp | 48 dp (padded) | Chart toolbar, chain header, filter rows |
| Row in sheet | 52 dp | full row | All sheets |

At 200% text scale the trigger grows in height (min height rather than fixed) and the value wraps to 2 lines max, then ellipsis.

## 10.5 Focus and semantics

- Trigger: `Semantics(button: true, label: 'Interval, 5 minutes', hint: 'Opens a list of 6 options', expanded: isOpen)`. The spoken label is field name plus value, never the value alone.
- Sheet: `Semantics(scopesRoute: true, namesRoute: true, label: 'Interval')`; focus moves to the selected row on open (or the title when nothing is selected); closing returns focus to the trigger.
- Row: `Semantics(selected: isSelected, inMutuallyExclusiveGroup: true)`; checked state is announced as `selected`.
- Segmented: `Semantics(container: true, label: fieldName)` with each segment a radio-style `selected` button.
- Back button and scrim tap dismiss with no change. Escape on hardware keyboards dismisses.
- Haptic: `selectionClick` on pick (FR-100); silent when haptics are off.
- Touch targets 48 dp everywhere; rows have 8 dp gaps in dense filters only if rows are chips (never below 48 dp hit area).

## 10.6 Implementation note

Built from Material primitives only, no third-party dropdown package:
- Trigger: `InkWell` over a `Container` (or `OutlinedButton` with a themed style) reading `context.sp` (`SpColors`) and `SpTypography`; no hard-coded colours.
- Sheet: `showModalBottomSheet(useSafeArea: true, showDragHandle: true, isScrollControlled: true)` with `ListView.builder` of `ListTile`-like rows (fixed `itemExtent` 52 for cheap layout) and `RadioGroup`/`RadioListTile` semantics or a custom `Semantics` wrapper.
- Segmented: M3 `SegmentedButton<T>` with the themed `SegmentedButtonThemeData` (5.6), `showSelectedIcon: false`.
- API: `SpPicker<T>({required List<SpOption<T>> options, required T? value, required ValueChanged<T> onChanged, String? label, String? errorText, SpPickerSize size, SpPickerVariant variant = auto})` with `SpOption({value, label, subtitle, icon, enabledReason})`. Label strings come from ARB keys (see part 14).
- Widget tests: golden for closed, open, selected, disabled, error in dark and light at 1.0x and 2.0x text; semantics test for label, selected and focus return.
