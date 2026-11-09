# ADR-0003: Chain cell equality excludes `asOf`; freshness via one shared check

Status: accepted · Date: 2026-11-06 · Refs: TR-6, TR-8; NFR-5, NFR-7, NFR-8, FR-38

## Context
ADR-0002 stamps every value with the frame `asOf` every 250 ms. If `OptionCell` (or `Quote`) stores `asOf` and includes it in
`==`, every cell is a new value on every flush and all 82 cells rebuild, failing NFR-5 ("rebuilds ≤ changed cells").

## Options
1. Store `asOf` in each cell and accept full rebuilds.
2. Store `asOf` in the cell but exclude it from `==`.
3. **No `asOf` field in `OptionCell`; `ChainView` carries `asOf` for the frame and `exAsOf` for exceptions; `asOfFor(id)` resolves it. Freshness computed by one pure `freshnessOf(...)` and emitted only when a flag flips.**

## Decision
Option 3 for the chain. For `Quote` (watchlist, cards) `asOf` and `seq` are kept as fields for the snapshot file and the merge
guard but excluded from `==`. Screens get stale state from `freshnessOf` driven by `freshnessTickProvider` (250 ms) and the
frame; a widget `select`s a `bool`/`Freshness`, so a keep-alive changes nothing visible. The same function is called
synchronously by the ticket's `confirm()` just before the POST (no await between check and send).

## Consequences
- Cell rebuilds = cells whose data changed (in practice most visible cells, since premiums follow spot; ~84 `Text` rebuilds at 4 Hz is affordable).
- Option 2 rejected: an `==` that ignores a field is a trap for the next developer; the type should not carry what it does not compare.
- One implementation of §3.1, tested at 4.9 / 5.0 / 5.1 s and +30 s skew; no per-cell timers.

## Who argued what
- dev-trading: raised the rebuild problem and proposed chain-level `asOf` + `ex`.
- dev-realtime: agreed, proposed `Freshness.of` as the single evaluator.
- dev-perf: the 250 ms timer must stop when the screen is hidden (adopted: autoDispose tick watched only by visible screens).
