# ADR-0020: 100 % line coverage gate with a fixed exclusion list; TDD as the working rule

Status: accepted · Date: 2026-11-07 · Refs: CR-1.14; NFR-17; TR-38; qa-lead test plan

## Context
The user wants scalability, extensibility and testability first, with 100 % coverage and proper TDD (CR-1.14). Today
there is no coverage measurement. `flutter test --coverage` writes `coverage/lcov.info`, but only for files that some
test imports: a file no test loads is simply absent, so "100 %" from lcov alone can be false. Flutter's lcov output also
does not apply `// coverage:ignore-*` markers reliably.

## Options
1. Report coverage, no gate.
2. A threshold (for example 90 %) with no exclusion list.
3. **A 100 % line gate over every `.dart` file under `lib/`, with an exact, short exclusion list, enforced by our own
   lcov check script that also counts files no test loaded.**

## Decision
Option 3, for `stock_pulse/lib`, `packages/option_math/lib` and `market_server/lib`.

**Exclusions (complete list; adding one needs an ADR amendment):**
| # | Pattern | Why |
|---|---|---|
| E1 | `stock_pulse/lib/main.dart` | one line, `void main() => bootstrap();`; `bootstrap()` itself is covered |
| E2 | `stock_pulse/lib/core/l10n/locales/**` | string tables (data, ADR-0018); interfaces, delegate, `plural` and `appStringsFor` are covered |
| E3 | lines between `// coverage:ignore-start` and `// coverage:ignore-end` whose first guarded line tests `kPerfProbe` | compiled out unless `--dart-define=PERF_PROBE=true` (TR-23); exercised by the perf runs, not unit tests |
| E4 | `market_server/bin/**` | process entry (argument parsing + `serve`); `lib/` holds the logic. (Outside `lib/`, listed for clarity) |

No other ignore markers are allowed; the script fails on an `ignore-line`, `ignore-file`, or an ignore block that does not
guard `kPerfProbe`. Generated code: none exists (NFR-18), so there is nothing else to exclude.

**How CI measures it (owner dev-perf; `tool/ci/coverage_check.dart`, pure Dart, own tests):**
```
cd stock_pulse
dart run tool/ci/coverage_check.dart --write-import-test     # writes test/_all_imports_test.dart (gitignored):
                                                              # imports every lib file, so unloaded files appear in lcov
flutter test --coverage                                       # coverage/lcov.info
dart run tool/ci/coverage_check.dart coverage/lcov.info --lib lib --min 100
cd ../packages/option_math && dart test --coverage=coverage && dart run coverage:format_coverage --lcov \
  --in=coverage --out=coverage/lcov.info --report-on=lib && dart run ../../stock_pulse/tool/ci/coverage_check.dart coverage/lcov.info --lib lib --min 100
(same for market_server; `coverage` is a dev dependency of the two Dart packages only)
```
The check: parses `SF:` / `DA:` records, drops excluded files and E3 blocks, lists every uncovered `path:line`, prints the
total, exits 1 below 100 %. A file absent from lcov after the import test is reported as uncovered.

**When it blocks:** from the end of refactor wave W1R. Until then CI prints the number without failing, so the refactor
stories can raise wave 0/1 code to 100 % without blocking each other.

**TDD rule (build brief):**
1. Red: write the test from the LLD test table (or the bug report) first and run it to see it fail for the right reason.
2. Green: the smallest code that passes. 3. Refactor with tests green.
- Every bug fix starts with a failing test that reproduces it.
- A test must assert behaviour. Tests that only execute lines to move the coverage number are rejected in review
  (`test-audit`), as are `expect(x, isNotNull)` on non-nullable values.
- Coverage is evidence, not the goal: the reviewer also checks each AC and failure case (CR-1.13) has a named test.

## Consequences
- 100 % is cheap only because controllers are widget-free (ADR-0009) and every I/O edge has an interface with a fake.
- Platform glue in Dart (`MethodChannelHaptics`) is covered through `TestDefaultBinaryMessengerBinding`; native
  Kotlin/Swift is outside `lib/` and covered by the device checklist.
- `coverage` becomes a dev dependency of `option_math` and `market_server` (TRD §1.1).
