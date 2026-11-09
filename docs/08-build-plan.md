# 08 · Build plan: StockPulse v2

Status: **v1.1** (matches `07-stories.md` v1.1, C1–C12; architect plan check applied) · Author: dev-lead ·
Sources: `07-stories.md`, `05-hld.md` §10.1–10.3, `06-lld/README.md` (D1–D13), thread `planning`.
Every story is on the work board as a task with status, owner, epic and a note giving wave + dependencies
(54 live stories; S-10 and S-28 are marked dropped and replaced by S-10a/b and S-28a/b).

## 1. How work moves

| Status | Who sets it | When |
|---|---|---|
| `todo` | dev-lead | story logged; deps not all `done` yet |
| `in_progress` | owner | all deps `done` (or the story runs on W0 fakes, as noted on the task) and no story of another owner in the same wave touches its files |
| `review` | owner | the story's LLD tests were written first and now pass, analyze shows 0 issues, only listed files changed |
| `done` | **dev-lead or reviewer only** | after a check: ACs mapped to tests, file list matches, no §10.2 signature drift, no codegen |
| `blocked` | owner | a dep slipped or a shared file is needed; post in thread `planning` the same hour |

A story is never `done` on the author's word alone. Slips are posted in `planning` (DoD item 6).

**Rolling waves.** Waves are integration gates, not barriers. An owner who finishes early may pull the next wave's story
when its deps are `done` and its files are its own (for example S-32, S-34 for dev-ai; S-35 for dev-perf). The wave exit
still waits for the checkpoint in §4.

## 2. Waves: owner → stories → files

### Wave 0 · stubs (all four in parallel, ≈ 3 days)
| Owner | Stories | Files |
|---|---|---|
| dev-realtime | S-1 | `packages/option_math/**` (not `payoff.dart`), `market_server/pubspec.yaml`, `market_reads.dart` (interface), `core/{market_time,network}/**` (not `api_client_lines.dart`), domain/data stubs, `core/providers.dart` shim, `test/helpers/test_server.dart` |
| dev-trading | S-2 | `core/theme/**`, `core/navigation/**`, `core/platform/haptics.dart`, `app/{order_outcome_listener,alert_banner_host}.dart`, `core/widgets/global_stale_banner.dart` |
| dev-ai | S-3 | `payoff.dart` (signatures), `features/strategy/**`, `market_server/lib/src/ai/ai_api.dart`, `core/network/api_client_lines.dart` |
| dev-perf | S-4 | `core/lifecycle/{screen_id,app_shell_controller,screen_visibility}.dart`, `core/storage/*` + `core/observability/*` interfaces, `test/helpers/` fakes, `stock_pulse/pubspec.yaml` |

### Wave 1 · M-A foundation
| Owner | Stories (order) | Files |
|---|---|---|
| dev-realtime | S-5 → S-6 → S-7 → S-9 → S-10a → S-10b → S-8 | `market_server/lib/src/{ist,market_clock,market_calendar,clock_scheduler,market_engine,instruments,models,tradable,ws_gateway,rest_api,debug_api}.dart`, `market_server.dart`, `bin/server.dart`, `core/market_time/**`, `core/network/**` (not `api_client_lines.dart`), `features/market/{domain,data}/**` |
| dev-trading | S-15, S-16 → S-18, S-17 | `core/platform/**`, android/ios haptics, `core/widgets/**`, `openers.dart`, `features/market/presentation/**` |
| dev-ai | S-19, S-20 → S-21, S-22 (then pull S-34, S-32) | `payoff.dart` + test, `market_server/lib/src/ai/**`, `api_client_lines.dart`, `features/ai_chat/{data,domain}/**` |
| dev-perf | S-11, S-12 → S-13, S-14 (then pull S-35) | `lib/{main,bootstrap,app}.dart`, `core/{lifecycle,storage,observability}/**`, CI, `test/architecture/**` |

S-17 builds on the S-1 fake `MarketRepository`; its live-socket AC is checked at the W1 checkpoint once S-10b is `done`.

### Wave 2 · M-B F&O core, AI client
| Owner | Stories (order) | Files |
|---|---|---|
| dev-realtime | S-23 → S-25 → S-24 → S-26 → S-49 | `option_instruments`, `option_pricer`, `market_engine` (S-23, then S-49 load mode), `broker`, `chain_book`, `expiry_service`, `rest_api` (orders), `ws_gateway` (chain), `clock_scheduler` hook, `bin/server.dart` (S-49), `features/{options,orders}/{domain,data}` (not trading's domain files) |
| dev-trading | S-28a → S-28b → S-27 → S-29, S-30, S-31 | ticket files + `orders/domain/{order_draft,order_validator,confirm_block,submit_phase,ticket_event}`, `features/options/presentation/**`, `chain_column.dart`, `risk_notice_screen.dart`, `openers.dart` (S-30), `app/order_outcome_listener.dart` |
| dev-ai | S-32 → S-33, S-34 | `features/ai_chat/presentation/**`, `features/strategy/**` |
| dev-perf | S-35, S-36, S-48a | `features/more/presentation/**`, `integration_test/lifecycle/**`, `test_driver/perf_driver.dart`, `tool/perf/frames.sh`, `integration_test/perf/watchlist_perf_test.dart` |

S-25 goes before S-24 so the ticket (S-28a/b) and the chain screen (S-27) unblock at different times.

### Wave 3 · M-C portfolio + alerts, M-D AI on live data
| Owner | Stories (order) | Files |
|---|---|---|
| dev-realtime | S-37 → S-38 → S-39 → S-40 | `broker.dart` (books), `rest_api.dart` (portfolio, then alerts, serial), `alerts_engine.dart`, `market_reads.dart`, `market_server.dart`, `debug_api.dart`, `features/{portfolio,alerts}/{domain,data}` (not `portfolio_summary.dart`), `integration_test/realtime/**`, `core/providers.dart` (deleted in S-40) |
| dev-trading | S-42, S-43, S-44 | `features/portfolio/presentation/**`, `features/portfolio/domain/portfolio_summary.dart`, `features/alerts/presentation/**`, `app/alert_banner_host.dart`, `openers.dart` (S-43), `nudge_strip.dart`, `summary_rows.dart`, SL/funds in `order_validator.dart` |
| dev-ai | S-45 | `integration_test/ai/**` |
| dev-perf | S-41, S-46 | `features/more/{debug_clock,socket_lab}/**` (architect approved), `more_controller.dart`, `core/storage/snapshot_scheduler.dart` |

### Wave 4 · device perf and polish
| Owner | Stories | Files |
|---|---|---|
| dev-perf | S-47, S-48 | `tool/perf/{startup.sh,summarize.dart}`, gating `integration_test/perf/**` (not `chat_perf_test.dart`), `docs/perf-results.md` |
| dev-trading | S-50 | `test/a11y/trading/**`, fixes in own files |
| dev-ai | S-51 (on the S-48a harness) | `test/a11y/ai/**`, `integration_test/perf/chat_perf_test.dart` |
| dev-realtime | perf fixes as raised | own files only |

## 3. Critical path

S-1 → S-5 → S-6 → S-7 → S-10a → S-8 → S-25 → S-28a → S-28b → S-42 → S-50, with the chain branch S-10a → S-23 → S-24 → S-27.
All of it except the trading tail sits on **dev-realtime**, which carries ≈ 22 working days in W1 against ≈ 10–12 for the
others (S = 1 d, M = 3 d, L = 5 d). So: dev-realtime works path stories first, S-41 is off its queue, the other three
pull ahead on fakes, and the S-10 / S-28 splits let S-24 and S-28a start on S-10a alone.
Rough length if nothing slips: W0 3 d, W1 ≈ 22 d, W2 ≈ 17 d, W3 ≈ 12 d, W4 ≈ 6 d → **≈ 12 weeks**.

## 4. Integration checkpoints (manager runs after each wave)

1. `flutter analyze` in `stock_pulse/`, `dart analyze` in `market_server/` and `packages/option_math/` → 0 issues.
2. `flutter test`, `dart test` in all three packages → all green; from W1 on, the S-14 CI checks (deny-list grep,
   `Timeline.` / `Colors.` greps, import-rule test, Must-FR trace script).
3. The wave's exit: W0 analyze clean · W1 M-A tests + FR-120…126 live · W2 J-2 · W3 J-3, J-4, J-5 · W4 NFR table filled.
4. Results posted in thread `planning`; red → the owning story goes back to `in_progress`, and stories that depend on it
   do not start. dev-lead spot-checks `done` stories against their file lists.

## 5. Shared files: one owner per wave

| File | Owner | Rule |
|---|---|---|
| `stock_pulse/pubspec.yaml` | dev-perf | W0 only (S-4); collect every package from the four LLDs first. A late need → ask in `planning`; dev-perf adds it **at a wave checkpoint**, never mid-wave |
| `market_server/pubspec.yaml`, `option_math/pubspec.yaml` | dev-realtime | same rule (S-1) |
| `core/providers.dart` (v1 file) | dev-realtime | re-export shim of the new `features/*/data/providers.dart` and `core/market_time/providers.dart` so v1 imports compile; each owner moves its own imports; deleted in S-40 |
| `core/network/api_client_lines.dart` | dev-ai | the one file under `core/network/` that dev-realtime does not own (D11) |
| `features/portfolio/domain/portfolio_summary.dart` | dev-trading | the one portfolio domain file that dev-realtime does not own (D3) |
| `lib/app.dart`, `main.dart`, `bootstrap.dart` | dev-perf | mounts trading's hosts (S-13); trading changes only the host widget files |
| `market_server.dart` | dev-realtime | calls dev-ai's `mountAiApi` in S-39; dev-ai never edits it |
| `rest_api.dart`, `ws_gateway.dart`, `broker.dart`, `market_engine.dart`, `clock_scheduler.dart` | dev-realtime | several stories, always serial in the order of §2 |
| `openers.dart`, `order_validator.dart` | dev-trading | S-16 → S-30 → S-43; S-28a → S-44 |
| §10.2 signatures | architect | any change is an HLD edit first, then the stub owner updates the stub |

## 6. Changes from the scrum master's first plan (all now in 07-stories v1.1)

| Change | Why |
|---|---|
| S-41 → dev-perf, W3 (C5, approved C12) | UI under More, which dev-perf owns; it only consumes `DebugClient` and the frames stream, which stay with dev-realtime; takes an M off the bottleneck |
| Rolling waves | dev-ai, dev-perf, dev-trading would otherwise idle for ~10 days in W1 |
| dev-realtime orders fixed (C6), S-25 before S-24 | ticket and chain screen unblock at different times |
| S-46 dep → S-8; S-38 after S-37; S-40 after both | correct API source; both edit `rest_api.dart` |
| `core/providers.dart` given an owner | v1 file not in any story; six v1 screens import it |
| File-list fixes from the architect check (C12) | S-4 lists the lifecycle stubs it creates; W1/W3 realtime rows exclude `api_client_lines.dart` and `portfolio_summary.dart` |

## 7. Schedule risks

| Risk | Effect | Mitigation |
|---|---|---|
| dev-realtime overload (path runs through it in W1–W3) | every later wave slips | path-first order, S-41 moved, S-10 split |
| §10.2 signature change mid-build | all consumers rework | architect gate; stubs frozen after the W0 checkpoint |
| Missing package found after W0 | pubspec edited mid-wave | full dependency list in S-4/S-1; adds only at checkpoints |
| Fakes drift from the real repos | W1 green on fakes, red at integration | fakes owned by the producer and updated in the same story |
| Flaky time-based tests (5.0 s edges, 300 ms re-listen) | red checkpoints | `FakeClock` / `FakeMarketClock` only; no real sleeps in unit tests |
| Device perf (W4) finds frame or RSS misses | late fixes across owners | S-48a harness and S-49 load flag in W2 give early signals; keep W4 buffer |
| Ticket (S-28a/b) on the path | trading tail and J-2 slip | split already done; S-28b may slip one day without moving S-27 |
