# ADR-0004: `ScreenVisibility` is the primary stream-lifecycle signal

Status: accepted, inputs amended by ADR-0015 (go_router: selected tab from the shell, observer on the root navigator) · Date: 2026-11-06 · Refs: TR-11…TR-13; FR-63, FR-82, FR-86, NFR-14

## Context
v1 uses an eager `IndexedStack`: all tabs are built and subscribed, and routes under a pushed screen keep ticking. FR-86 needs
hidden tabs and covered routes to release their price streams; NFR-14 checks exact sub counts; FR-63 needs chat cards to
unsubscribe within 1 s when less than 50 % visible.

## Options
1. Riverpod 3 listener pausing under `TickerMode(false)` (`ref.onCancel`/`ref.onResume`), no explicit signal.
2. **Explicit `screenVisibleProvider(ScreenId)`** = tab selected AND no opaque route above (via `VisibilityRouteObserver`); controllers `ref.listen` it and cancel / re-listen.
3. `visibility_detector` everywhere (or only for chat cards).

## Decision
Option 2, with lazy tabs (unvisited tabs not built) and `TickerMode` per tab kept as a backup. Non-opaque sheets do not
cover. Chat cards: an in-house `LiveWhenVisible` (viewport-rect check on scroll, 200 ms throttle, ≥ 50 %) AND
`screenVisibleProvider(ScreenId.ai)`; no `visibility_detector`. Repository linger 300 ms before unsubscribe.

## Consequences
- Explicit and testable: FR-124 counts assert release; no reliance on framework pausing semantics that could change.
- FR-63 timing: 200 ms check + 300 ms linger + send ≈ 0.6 s < 1 s.
- Ticket and alert-create controllers own their quote subs (the opaque risk notice pauses the chain).
- One more provider wired into every price controller; LLDs must show the `ref.listen` pattern.

## Who argued what
- dev-perf: first proposed option 1 with option 2 as fallback, then made option 2 primary after critiques.
- dev-realtime: asked for option 2 primary ("riskiest bit for my sub-count tests").
- dev-trading: first asked for option 2, then accepted option 1, now on option 2; asked that the ticket owns its subs (accepted).
- dev-ai: proposed `visibility_detector` for cards; **overruled**: new dependency, and it cannot see hidden tabs or covered routes (dev-perf), so it would still need option 2; the 50 % check is ~40 lines in-house.
