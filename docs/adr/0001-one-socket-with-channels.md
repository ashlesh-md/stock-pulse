# ADR-0001: One WebSocket with channels

Status: accepted · Date: 2026-11-06 · Decider: architect · Refs: TR-1, TR-7, TR-9, TR-11; FR-29a, FR-84, NFR-14

## Context
v1 has one socket carrying `ticks` and `order` frames, symbols only, capped at 50 per session (`ws_gateway.dart`), and `order`
frames broadcast to every session. v2 adds a 41-strike chain (82 contracts), account streams (orders, positions, funds,
settlement, alerts) and AI chat. The architect review (H1) found the cap conflicts with a chain built from per-contract subs.

## Options
1. **One socket, `channel` field on subscribe** (`quotes`, `chain`, `orders`, `alerts`), one per-session `seq`.
2. One socket per channel (market, account, AI).
3. Per-contract quote subscriptions for the chain on the v1 protocol, cap raised.

## Decision
Option 1. Chain is one subscription per (underlying, expiry) with a strike range, max 2 per session, outside the quote cap
(now 100). Account frames go only to sessions subscribed to `orders`/`alerts`. Quote and chain resync use a socket `resync`
op; account state reloads over REST and merges by `version`/`alertId`. AI is not on the socket (ADR-0006).

## Consequences
- One reconnect/backoff/heartbeat/seq state machine (v1 `MarketSocket` reused); one place to pause in background.
- A single `seq` covers all channels, so a gap in any channel triggers one resync of everything; acceptable at ≤ 9 frames/s.
- Chain range updates (`updateRange`) replace the range in place; no unsubscribe/subscribe churn on scroll.
- `SocketMessage` becomes a sealed family; Socket Lab shows the channel per frame.

## Who argued what
- dev-realtime: proposed option 1 and rejected option 2 ("multiplies reconnect, backoff and seq state").
- dev-trading: rejected option 3 (82 `StreamProvider.family` subs, breaks FR-29a); asked for `updateRange` on one sub.
- dev-ai: wanted chain snippets in cards on the quote path (accepted: ≤ 10 contracts per card, counted in the cap).
- Architect review H1 raised the cap conflict; PRD v1.1 C3/C9 adopted it.
