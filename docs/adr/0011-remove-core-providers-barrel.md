# ADR-0011: Delete `core/providers.dart` now; feature DI files replace it

Status: accepted · Date: 2026-11-07 · Refs: CR-1.9, CR-1.1; ADR-0009; build plan §5 (was: deleted in S-40)

## Context
`stock_pulse/lib/core/providers.dart` is an 11-line re-export barrel created in S-1 so v1 imports kept compiling after
providers moved next to what they build. The plan deleted it in S-40 (wave 3). Today 11 files import it: four controllers
(`watchlist_controller`, `stock_detail_controller`, `portfolio_controller`, `socket_lab_controller`), two widgets
(`socket_lab_screen`, `order_update_listener`) and five tests. The user asked: is it needed? Justify or remove (CR-1.9).

## Options
1. Keep it to S-40 as planned.
2. Keep a barrel, re-pointed at the new feature DI files, as a convenience import.
3. **Delete it in the first refactor story; every importer imports the specific DI or application file it needs.**

## Decision
Option 3. **It is not needed.** It existed only to keep v1 imports compiling during the move, and with ADR-0009 it is
harmful:
- It exports repository providers to anyone, so presentation files reach the data layer through it (two widgets do today).
  The layer test (TR-28) cannot see through a re-export to tell which provider a file uses.
- It couples core to every feature (`core/` exporting `features/**`), against ADR-0010.
- A barrel hides each file's real dependencies; a reviewer reading imports learns nothing, and adding a feature means
  editing a shared file that has one owner.

**What replaces it:** nothing shared. Each consumer imports the exact file:
| Consumer | Imports |
|---|---|
| application controller needing a repository | `package:stock_pulse/features/<f>/<f>_providers.dart` |
| application needing socket / clock / storage | `package:stock_pulse/core/<module>/<module>_providers.dart` or `core/<module>/application/...` |
| presentation | the controller's file in `application/` only |
| tests | the provider being overridden, from its own file |

## Consequences
- S-40 loses the "delete shim" item; build plan §5 row for `core/providers.dart` is removed.
- The delete is one repo-wide edit (11 files, other owners' files included). It runs in refactor story R-1a while the other
  developers are stopped, so no file is edited by two people at once.
- No barrel files at all in `lib/` (`export` directives are allowed only in `packages/option_math/lib/option_math.dart`,
  the package's public API). Checked by the CI grep in TR-28.
