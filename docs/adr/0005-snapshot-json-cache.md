# ADR-0005: Cache-first start with `snapshot.json` via `path_provider`

Status: accepted · Date: 2026-11-06 · Refs: TR-14…TR-16; FR-80, FR-81, FR-87, FR-112, NFR-1, NFR-2

## Context
NFR-1 (first frame p50 ≤ 800 ms) and NFR-2 (cached content ≤ 1.0 s) on a mid-range Android. No codegen (NFR-18). v1 has
no storage package. Small flags also need persistence (risk-notice ack, haptics toggle, alert seen-set).

## Options
1. **One JSON file (`dart:io` + `path_provider`), read future started in `main()` and not awaited.**
2. `shared_preferences` with JSON blobs.
3. `sqflite` / `drift` / `hive` / `isar`.

## Decision
Option 1: `snapshot.json` (schemaVersion, savedAt, watchlist quotes with `asOf`, positions, holdings, summary; ≤ 64 KB) and a
separate `prefs.json` (flags, seen-set ≤ 500, last chain underlying), both atomic tmp+rename with a single writer. Snapshot
saved on `onHide`, every 30 s only if structurally dirty (not on LTP ticks), and after a resync only while live. Invalid
(> 7 days, wrong schema, corrupt) → delete, one `cache_discarded` log. Cached quotes carry `fromCache: true` and are stale
until their first live frame, whatever their seq. Orders and chain prices are never cached.

## Consequences
- One new dependency; its first channel call happens inside the un-awaited future.
- No migrations: a schema bump discards the cache (acceptable for a cache).
- Prefs are separate so the 7-day snapshot discard never resets the risk-notice ack.

## Who argued what
- dev-perf: proposed option 1; rejected 2 (async init tempts an await in `main`) and 3 (native weight, codegen).
- dev-trading: "dirty" = structural only; asked for a local prefs store for the ack (folded into `prefs.json`, not `shared_preferences`).
- dev-realtime: `fromCache` flag; save after resync only when live; cache only `lastChainUnderlying`, never chain prices.
- An `origin: resumed` state was proposed and **dropped**: values replayed after re-listen age out by §3.1 normally.
