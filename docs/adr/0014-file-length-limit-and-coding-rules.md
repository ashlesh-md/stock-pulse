# ADR-0014: 300-line file limit (CI) and coding rules for code that reads as written by a careful person

Status: accepted · Date: 2026-11-07 · Refs: CR-1.3, CR-1.4; TR-30, TR-31; `docs/team/build-brief.md` rules

## Context
The user wants no file over 300 lines (CR-1.4) and code without unneeded comments or "AI-looking" boilerplate (CR-1.3).
Today 3 app files and 8 server files exceed 300 lines: `candle_chart.dart` 463, `market_socket.dart` 431,
`stock_detail_screen.dart` 425; `market_engine.dart` 542, `ws_gateway.dart` 509, `instruments.dart` 480,
`answer_builder.dart` 383, `card_json.dart` 364, and tests `protocol_v2_test.dart` 414, `answer_builder_test.dart` 405,
`market_test.dart` 348. Many files open with comments that narrate the story (`// S-1 stub`, `// §10.2`, `// TODO(S-28a)`).

## Options
1. Reviewer checks only.
2. **A CI script that fails on any hand-written Dart file over 300 lines, plus written coding rules that the reviewer checks.**
3. A lint plugin (`custom_lint`) for length. Needs a package and a plugin host; more than the job needs.

## Decision
Option 2.

**`tool/ci/file_length_check.dart`** (pure Dart, no packages; owner dev-perf):
- Scans `stock_pulse/{lib,test,integration_test,tool}`, `market_server/{lib,bin,test}`, `packages/option_math/{lib,test}`
  for `*.dart`.
- Counts physical lines (as `wc -l`). Limit 300. No exclusions; there is no generated code (TR-31). The only allowed
  exception is a file listed in `tool/ci/file_length_allowlist.txt` with a reason, and that file starts empty and must
  stay empty unless the architect approves an entry.
- Prints `path: N lines (limit 300)` for each offender and exits 1. Runs in CI before tests, and locally with
  `dart run tool/ci/file_length_check.dart`.
- Has its own test (`test/tool/file_length_check_test.dart`) over a temp directory.

**How to stay under 300:** split by responsibility, not by line count. A screen keeps its scaffold and moves sections to
`widgets/`; a painter moves maths to a pure helper (`candle_geometry.dart`) and keeps `paint`; a socket client moves wire
decoding and subscription bookkeeping into their own files; a test file splits by `group`.

**Coding rules (CR-1.3; copied into the build brief):**
1. Comments say *why*, never *what*. Delete comments that restate the code, narrate history (`// moved from v1`,
   `// S-12 stub`, `// now uses X`), cite documents (`// §10.2`, `// D4`, `// FR-31`) or apologise. Requirement IDs belong
   in test names and the LLD, not in production code.
2. Doc comments (`///`) on public API only when they add something the name and type do not: a unit, a range, a threading
   or lifecycle rule, a failure mode. No `/// The repository.` on `final MarketRepository repository`.
3. `TODO` only as `// TODO(owner): action` with a story id in the task board, never as a plan of future work in prose.
4. No boilerplate the LLD did not ask for: no unused interfaces, no "manager/helper/util" classes with one method, no
   `toString` overrides except on state and value classes, no defensive `try/catch` that rethrows, no `assert` restating a
   non-null type.
5. Names over comments: if a block needs a comment to explain what it does, extract a well-named function.
6. Small functions (aim ≤ 40 lines), early returns over nested `if`, `switch` expressions over `if` chains on sealed types,
   no `default` branch on a sealed or enum switch.
7. No commented-out code, no `print`, no `debugPrint` outside `core/observability`.
8. Consistent vocabulary: one word per idea across the app (`instrumentId`, not `symbol` in one file and `ticker` in another).
9. Tests read as specifications: `test('rejects a limit price outside the band')`, arrange / act / assert, one behaviour each,
   no comments that repeat the test name.

## Consequences
- 11 files must split before the gate turns on (refactor stories, `06-lld/README.md` §6); the gate is blocking from the
  end of refactor wave W1R.
- The reviewer checklist adds rules 1–9; `review` / `code-review` flags narrating comments as must-fix.
- Some cross-references from code to docs are lost; test names and LLD tables carry the FR/NFR trace instead (TR-35).
