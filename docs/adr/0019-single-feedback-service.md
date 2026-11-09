# ADR-0019: One feedback service; only one snackbar on screen, deduped by key, replaced not stacked

Status: accepted, **amended v2.2** (v2.1 rule 3 = FR-157 priority + one waiting slot; v2.2 rule 2 = FR-156 4 s repeat window, disabled actions never snack) · Date: 2026-11-07 · Refs: CR-1.2; FR-156, FR-157; UX spec (single-snackbar rules, ux-designer); TR-37

## Context
Snackbars are shown from five places with `ScaffoldMessenger.showSnackBar` (`SpSnack`, `order_sheet.dart` twice,
`portfolio_screen.dart`, `order_update_listener.dart`, `socket_lab_screen.dart`). `showSnackBar` queues: five bad taps on a
blocked Confirm show five snackbars one after another for 20 s (CR-1.2). The message text is often built in the widget
from `failure.message`.

## Options
1. Call `hideCurrentSnackBar()` before every `showSnackBar`. Each caller must remember; no dedupe; still in widgets.
2. **A `FeedbackController` in the application layer that holds the one current message, and a single `FeedbackHost`
   that renders it.** Callers are controllers.
3. An overlay toast package. New dependency; same rules still needed.

## Decision
Option 2. Module `core/feedback/` (layered). Owner: dev-trading (owner of `SpSnack` and the snack design).

```dart
// domain/feedback_message.dart
enum FeedbackKind { info, success, error }                 // visuals only
enum FeedbackPriority { info, error, orderOutcome }         // FR-157 order: orderOutcome > error > info
@immutable
final class FeedbackMessage {
  const FeedbackMessage({required this.key, required this.text, this.kind = FeedbackKind.info,
    this.actionLabel, this.action, this.persist = false, FeedbackPriority? priority})
    : priority = priority ?? (kind == FeedbackKind.error ? FeedbackPriority.error : FeedbackPriority.info);
  final String key;            // identity for dedupe, e.g. 'order.rejected.<orderId>', 'link.invalid'
  final String text;           // already localised (stringsProvider)
  final FeedbackKind kind;
  final String? actionLabel;
  final FeedbackAction? action; // sealed: OpenLocation(String path) | ReplyToSender(String actionId)
  final bool persist;          // rejections: until dismissed (03b 5.13)
  final FeedbackPriority priority; // order outcome listener passes orderOutcome for fill, rejection, status unknown
}
// application/feedback_controller.dart
final class FeedbackController extends Notifier<FeedbackMessage?> {   // state = the message on screen
  void show(FeedbackMessage m);      // rules below
  void dismissed(String key);        // host calls when the snackbar closes; promotes the waiting message
  void clear();                      // clears the shown and the waiting message
  void actionTapped(FeedbackMessage m);            // host calls; OpenLocation is handled by the host itself
  Stream<FeedbackReply> get replies;               // (key, actionId) for ReplyToSender taps
}
final feedbackControllerProvider = NotifierProvider<FeedbackController, FeedbackMessage?>(FeedbackController.new);
// presentation/feedback_host.dart: the only file that calls showSnackBar (CI grep)
```

**Rules (the UX spec owns the wording; these are the mechanics):**
1. At most one snackbar on screen. The host calls `hideCurrentSnackBar()` then `showSnackBar(...)`; it never queues.
2. Same `key` as the message on screen, **or a key shown less than 4 s ago** (FR-156, UX 12 rule 2) → dropped: no
   flicker, no timer restart, no announcement. The controller keeps `key → lastShownAt` from the injected `Clock`.
   Five identical rejections in a row = exactly one snackbar and an empty waiting slot.
2a. **A disabled action is a state, not an event** (FR-156, UX 12.1): a tap on a disabled control (blocked Confirm,
   stale price, market closed) never calls `show`. The widget focuses its inline reason line and fires the haptic;
   0 snackbars.
3. Different key (FR-157): if its `priority` is **≥** the shown one's, it replaces the shown one at once. If it is
   **lower**, it goes into the **one waiting slot** (newest wins, so the older waiting message is dropped) and is shown,
   with a fresh timer, when the shown message is dismissed. A waiting message whose key equals the shown key is ignored.
   A lower message is never dropped for being lower; only an older waiting message is replaced (v2.0's "info over a
   visible error is dropped" is withdrawn).
4. `persist` messages stay until closed or replaced by a message of equal or higher priority; others last 4 s (6 s with
   an action).
5. A message's `action` is data, not a closure, so state stays comparable and testable; the host maps it
   (`OpenLocation` → `router.go`; `ReplyToSender` → `actionTapped`, and the controller that sent it listens to `replies`
   filtered by its key prefix, for example the strategy controller handling "Start new" after `otherChain`).
6. Screen-reader announcement once per shown message (moved from `SpSnack`).

**Host placement:** `FeedbackHost` sits in `MaterialApp.router(builder:)` above every route with its own
`scaffoldMessengerKey`, so a message survives route changes and the ticket sheet closing. Alert banners (top, queued,
`AlertBannerHost`) are a different component with their own queue rules and are not changed.

**Who calls `show`:** application controllers only (ticket on rejected/timed-out, never on a disabled Confirm, chain on `otherChain` / `full`,
portfolio on load failure, order outcome listener controller on fills, push foreground). Widgets never call it.

## Consequences
- CR-1.2 holds by construction: a test taps a disabled Confirm 5 times in 1 s and finds **0** `SnackBar`s and the
  reason line focused; a test sends the same rejection key 5 times and finds exactly 1 `SnackBar`, waiting slot empty;
  a fake clock shows the same key is accepted again after 4 s.
- FR-157 test (controller, no widgets): fill shown → `info A`, `info B` → state is still the fill, waiting is B;
  `dismissed(fill)` → state is B; A never shows.
- `SpSnack` is folded into `FeedbackHost` (visual spec unchanged). The five direct `showSnackBar` calls move into
  controllers as `show(...)` calls (refactor stories for dev-trading and dev-perf).
- Callers must choose keys well; the rule of thumb is `<feature>.<reason>[.<id>]`, written into the trading LLD.

## Change log
- v2.1 (2026-11-07, architect): rule 3 replaced to match PRD FR-157 (raised by scrum-master, R-2 needs one rule):
  `FeedbackPriority` added, one waiting slot, newest wins. Kind stays visual; priority defaults from kind.
- v2.2 (2026-11-07, architect): gaps raised by product-manager. Rule 2 adds FR-156's "shown < 4 s ago" repeat window;
  rule 2a: a disabled action shows its inline reason + haptic and never a snackbar (UX 12.1), so the blocked-Confirm
  test expects 0, not 1. Example key `ticket.blocked.stale` removed.
