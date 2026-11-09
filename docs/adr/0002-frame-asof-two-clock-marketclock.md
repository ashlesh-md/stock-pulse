# ADR-0002: Frame-level `asOf` and a two-clock `MarketClock`

Status: accepted · Date: 2026-11-06 · Refs: TR-2…TR-5; PRD §3.1, §3.2; FR-91, FR-93…95, FR-111, FR-116, FR-120

## Context
PRD §3.1 makes staleness block orders. v1 sends `t` = last trade time, so a quiet deep-OTM strike would look stale and block
its own ticket. PRD §3.2 needs a virtual clock with `jumpTo` (09:14:50, 15:19:50, next day) and a demo mode that is Open at any
hour. If the same clock drives both, a debug jump of +5 hours makes every price "5 hours old".

## Options
- `asOf`: (a) per value on the wire; (b) **one `asOf` per frame confirming every subscribed value, exceptions in `ex`**; (c) last trade time.
- Clock: (a) one virtual clock for everything; (b) **two times: wall time (asOf, keep-alive, staleness) and market time (phase, expiry, pricing T, candles, order timestamps)**.

## Decision
`asOf` (b) plus a `ka` frame every 1 s for unchanged subs (worst healthy age ≈ 1.25 s). Clock (b): `MarketClock.wallNow()`,
`marketNow() = wallNow + marketOffset`, `jumpTo(t)` changes the offset only. The client derives `serverNow` from
`welcome`/`pong` `serverTime` (wall) and `marketNow = serverNow + marketOffsetMs` from the `clock` frame. The today line,
theta and expiry badges use market time; freshness uses wall time only.

## Consequences
- Per-symbol freeze (FR-121) is just "remove from frames and `ka`, list in `ex`"; stale is exact per instrument.
- Wire cost is one field per frame instead of ~82; but frame `asOf` advances every 250 ms, which forces ADR-0003.
- Debug jumps never cause false stale; scheduler replays crossed boundaries; backward jumps only via reset.
- Two clocks must never be mixed: unit tests cover a +5 h jump with 0 stale values.

## Who argued what
- Architect review H2: `asOf` = last server confirmation, compare to server time.
- dev-realtime: proposed frame-level `asOf` + `ex`, rejected per-cell `asOf` (~2× bytes), and proposed separating wall from market time.
- dev-perf: required the offset to be set before any stale decision (accepted: nothing is live before `welcome`).
- dev-ai: today line must agree with the chain under the demo clock (accepted via `marketOffsetMs`).
