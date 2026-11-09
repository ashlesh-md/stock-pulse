# 03 · UX spec part 12: Feedback, one snackbar at a time (v2.0)

Owner: ux-designer · Part of `../03-ux-spec.md` v2.0 · PRD FR-156, FR-157 (CR-1.2), F17 · Component `SpSnack`
(03b 5.13) shown only through the single feedback service (architect, HLD v2).

## 12.1 Which channel for which message

Pick the channel by **what the message is about**, not by how important it feels.

| Channel | Use for | Lifetime | Examples |
|---|---|---|---|
| **Inline** (next to the thing) | A field, a section or an action that is blocked right now | Until the cause is fixed | Field errors, the reason line above a disabled Confirm, server rejection banner inside the ticket, `ErrorView` / `EmptyView`, chart chips "Not enough data" |
| **Banner** (under the app bar, pushes content) | A **state** of the app or market that lasts | Until the state ends | Stale feed "Prices not live since 09:31:07" (FR-90), alert hit (FR-52, 8 s), Pre-open "Options open at 09:15", Session expired (proposal, Q-UX-3) |
| **Snackbar** (`SpSnack`, above the bottom bar) | An **event** that just happened, or an undo | 4 s, 6 s with an action | Order filled / rejected / unknown, Undo delete, "Link not available", "Couldn't save drawing", system events (square-off, settlement) |
| **Dialog** | Only to confirm a destructive action | Until answered | Reset demo account, Clear drawings |

Rules that follow from this:

- **A state is never a snackbar.** Stale, offline, closed and blocked are shown where they are (badge, banner,
  reason line). So a trader tapping a disabled Confirm five times gets **no snackbar**: the reason line is focused
  and a light haptic plays (main spec §4). This removes the most common cause of stacking.
- **A message tied to a field is never a snackbar.** The field shows it.
- The ticket's server rejection is inline in the sheet (the sheet stays open). Only outcomes after the sheet closes
  are snackbars.

## 12.2 The one-snackbar rule (FR-156, FR-157)

Every snackbar has a **key** (stable id of the message kind plus its subject), a **priority** and a duration.

| Priority | Kind | Examples |
|---|---|---|
| 3 · Order outcome | Fill, rejection after close, status unknown, settlement, square-off | `order_filled:<orderId>` |
| 2 · Error | Something failed that the user tried | `chart_interval_failed:15m`, `link_invalid` |
| 1 · Info | Confirmation, undo, limits | `chart_studies_limit`, `alert_deleted:<id>` |

When a new message M arrives and V is visible:

| # | Case | Result |
|---|---|---|
| 1 | No snackbar visible | Show M |
| 2 | M.key = V.key, or M.key was shown < 4 s ago | **Drop M.** V's timer is not reset; nothing re-animates; screen reader says nothing |
| 3 | M.priority ≥ V.priority, different key | **Replace:** V leaves at once (no exit animation), M shows |
| 4 | M.priority < V.priority | M goes to the **one waiting slot** (newest wins, older waiting message is discarded); shown when V closes |
| 5 | Waiting message whose screen is gone (e.g. Undo for a sheet that closed) | Discarded when its turn comes |

There is **never a queue longer than one** and never two snackbars on screen.

**Placement:** 8 dp above the nav bar, or above a screen's pinned bottom bar (stock page Buy/Sell); inside an open
sheet, above the sheet's pinned bar, **never over Confirm**; landscape chart: bottom-left, ≤ 400 dp wide. Swipe
down or the ✕ (48 dp) dismisses.

**Accessibility:** announced once as a polite live region; a replaced message announces the new one; a dropped one
announces nothing. The timer pauses while it has screen-reader focus and follows the OS "time to take action"
setting when that is longer. The action button is ≥ 48 dp and is reachable by focus.

## 12.3 Copy patterns

Pattern: **What happened[: detail] · Action**. Sentence case, no full stop on single phrases, no exclamation marks,
numbers exact.

| Key | Priority | Copy | Duration / action |
|---|---|---|---|
| `order_filled:<id>` | 3 | Filled: Bought 130 NIFTY 24500 CE at 141.25 | 6 s · View |
| `order_rejected:<id>` (sheet already closed, via resync) | 3 | Rejected: Sell 10 RELIANCE · Price outside band | 6 s · View |
| `order_unknown:<id>` | 3 | Order status unknown. See Orders | 6 s · View |
| `order_squared_off:<id>` | 3 | MIS RELIANCE squared off at 15:20 | 6 s · View |
| `order_settled:<id>` | 3 | NIFTY 11 Nov 24500 CE settled at intrinsic ₹6,500.00 | 6 s · View |
| `chart_interval_failed:<iv>` | 2 | Couldn't load 15m · showing 5m | 4 s · Retry |
| `chart_drawing_save_failed` | 2 | Couldn't save drawing | 4 s |
| `link_invalid` | 2 | Link not available | 4 s |
| `expiry_rolled:<date>` | 1 | 11 Nov expired · showing 18 Nov | 4 s |
| `chart_studies_limit` | 1 | Up to 4 studies · remove one to add another | 4 s |
| `chart_study_removed:<id>` | 1 | SMA 20 removed | 4 s · Undo |
| `chart_line_deleted:<id>` | 1 | Line deleted | 4 s · Undo |
| `alert_deleted:<id>` | 1 | Alert deleted | 4 s · Undo |
| `alert_saved:<id>` | 1 | Alert set: RELIANCE ≥ 1,500.00 | 4 s |
| `ai_answer_stopped` | 1 | Answer stopped | 4 s |

Repeated bad taps (F17): a rejected order resubmitted with the same reason produces the inline banner again (the
sheet is open) and no snackbar; any snackbar with the same key inside 4 s is dropped (rule 2).

## 12.4 Haptics with feedback

Haptics pair with a visible message, never alone: success on fill (FR-100), rejection on reject, light tick on a
disabled-button tap and on picker/snap changes. A dropped snackbar plays no haptic.
