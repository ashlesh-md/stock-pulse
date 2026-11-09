# ADR-0007: `packages/option_math` shared package and its ownership

Status: accepted · Date: 2026-11-06 · Refs: TR-18, TR-26; FR-27, FR-70…FR-73

## Context
Black-Scholes prices the chain on the server, greeks show on the strike sheet, the builder draws a today line, and the AI
payoff card shows max profit/loss and breakevens computed on the **server**. Two implementations would disagree.

## Options
1. Pricing in `option_math` (dev-realtime), payoff kink maths in the app's strategy feature (dev-realtime's proposal).
2. **One package with two libraries and two owners: `pricing.dart` (dev-realtime) and `payoff.dart` (dev-ai).**
3. Server endpoint that returns payoff curves.

## Decision
Option 2. `pricing.dart`: `bsPrice`, `greeks`, `yearsToExpiry(marketNow, expiryAt)`. `payoff.dart`: `payoffAtExpiry`,
`payoffSummary` (exact: evaluate at 0 and each strike, tails by slope; no sampling), `valueToday` (uses `bsPrice`).
Pure Dart, no Flutter import, path dependency of both `market_server` and `stock_pulse`. The smile and OU IV model stay in
the server (`option_pricer.dart`), not in the package.

## Consequences
- The AI card summary and the builder call the same `payoffSummary`, so no cross-check test is needed.
- Option 1 rejected: the server answer builder cannot import a Flutter feature folder.
- Option 3 rejected: ties data to screen size and adds a round trip on every leg edit.
- Each owner writes the package tests for their library; the architect reviews changes to the public API.

## Who argued what
- dev-realtime: owns the package, wanted payoff in the client feature.
- dev-ai: asked for `payoffSummary` in the package so server and client cannot disagree (**accepted**).
- dev-trading: greeks sheet consumes `greeks` only.
