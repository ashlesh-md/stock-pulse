# ADR-0006: AI chat answers over HTTP NDJSON

Status: accepted · Date: 2026-11-06 · Refs: TR-17; FR-60…FR-67

## Context
Answers must stream (first card painted before the stream ends), be cancellable, and survive a mid-stream error with the
cards already received. Cards that tick must use the normal quote path.

## Options
1. WebSocket `ai.ask` / `ai.card` / `ai.done` frames on the market socket.
2. **`POST /api/v1/ai/ask` returning NDJSON** (`start`, `card`, `delta`, `done`, `error`).
3. Server-Sent Events.
4. One JSON response.

## Decision
Option 2. The server is an `async*` generator with `shelf.io.buffer_output: false`; cancel = client aborts the request
(`http.AbortableRequest`), the generator stops at its next yield. Cards carry ids, `v`, `asOf`, a first-paint snapshot,
`fallbackText` and actions (ids, side, `lots: 1`, never a price). Live values come from `liveQuoteProvider` with
`throttleMs: 1000`. Delays go through `MarketClock.delay` so tests wait 0.

## Consequences
- AI never consumes the market `seq`; a lost card cannot force a quote resync.
- Testable with curl and a plain HTTP test; `activeAiAnswers` proves cancellation.
- Two transports in the app (socket + HTTP streaming); `ApiClient.postLines` is the only new client code path.

## Who argued what
- Architect review §3.3 leaned to option 2; PRD v1.1 C11 / FR-67 adopted it.
- dev-ai: designed the event set; rejected SSE (extra framing, no Dart advantage) and option 4 (fails FR-60).
- dev-realtime: "NDJSON stays off the socket seq"; delays on the clock hook.
- dev-trading: no `limitPrice` from cards (accepted).
