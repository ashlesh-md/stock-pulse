# ADR-0013: Package imports everywhere, enforced by `always_use_package_imports`

Status: accepted · Date: 2026-11-07 · Refs: CR-1.6; TR-29; `analysis_options.yaml`

## Context
`lib/` uses relative imports (`'../../../core/providers.dart'`); 74 files have a `../` import. Tests already use
`package:stock_pulse/...` for `lib/` and relative paths for `test/helpers/`. The user prefers package imports unless there
is a reason not to (CR-1.6).

## Options
1. **`always_use_package_imports`**: every import of a `lib/` file is `package:stock_pulse/...`.
2. `prefer_relative_imports`: relative inside `lib/`, package from outside.
3. No rule (mixed).

## Decision
Option 1, in `stock_pulse`, `market_server` and `option_math`.
- **One URI per library.** Mixing `package:` and relative URIs for the same file can load it twice; `MarketRepository`
  from one URI is then not the type from the other. Tests that import `lib/` by package and `lib/` that imports itself
  relatively are the classic way this bites. One style removes the class of bug.
- **Imports state the layer.** `package:stock_pulse/features/market/data/live_market_repository.dart` says what it is;
  `'../../data/...'` says only where it is from here. The layer test (TR-28) and reviewers read the path directly.
- **Moves are safe.** ADR-0009/0010 move most files once; package imports do not change when the importing file moves,
  only when the target moves, and the IDE rewrites those.
- Tests: `lib/` files by package (already true; `avoid_relative_lib_imports` stays on). Files under `test/` itself
  (`test/helpers/fake_market_repository.dart`) cannot be package-imported, because `test/` is not in the package; those stay
  relative. That is the only relative import allowed.

## Consequences
- Migration is automatic: `dart fix --apply --code=always_use_package_imports` per package, run once by dev-perf in R-0
  while the other developers are stopped (it touches every file).
- Lines are longer; `dart format` wraps nothing in imports, so a long import is one line. Accepted.
- `directives_ordering` is enabled with it, so imports sort as `dart:`, `package:` (third party and own), then relative
  test helpers.
