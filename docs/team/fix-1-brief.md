# FIX-1 batch brief (all four developers, in parallel)

Read first: `docs/team/build-brief.md` (rules), `docs/10-change-request-2.md`, `docs/team/reviews/code-review-1.md` (53 findings), `docs/team/bugs.md` (user bugs B1-B8).

## Your work, in your own files only
1. Every code-review-1 row whose file you own (ownership below). Critical and High first.
2. Your user bugs from `bugs.md` (B1 and B2 are fixed; B3-B8 are open). Write a failing test first.
3. Your CR-2 items from `docs/10-change-request-2.md`, unless already built (check the code first; finish what is half-built).
4. **Coverage to 100%** on your files: `flutter test --coverage` and `dart run tool/ci/coverage_check.dart coverage/lcov.info` (from `stock_pulse/`). It lists uncovered lines by file. Tests must assert behaviour.
5. Remove comments that cite stories, FRs, sections or decisions (`// S-12`, `// FR-31`, `// §10.2`, `// D4`), and dead files you own (the review lists 13).

## Ownership
| Owner | Files |
|---|---|
| dev-realtime | `market_server/**` except `lib/src/ai/**`; `packages/option_math/lib/src/pricing.dart`; app `core/{network,market_time,error,config}/**`; `features/{market,options,orders,portfolio,alerts}/{domain,data,di/*_data_providers.dart}` |
| dev-trading | app `features/{market,options,orders,portfolio,alerts}/{application,presentation,di/*_providers.dart}`; `features/chart/**` except the dev-ai chart files; `core/{theme,feedback,l10n,assets,platform,widgets}/**` |
| dev-ai | app `features/{ai_chat,strategy}/**`; `features/chart/domain/indicators/**`, the studies sheet/chips/panes (`features/chart/presentation/studies/**`), `fib_*`; `market_server/lib/src/ai/**`; `packages/option_math/lib/src/payoff.dart` |
| dev-perf | app `lib/main.dart`, `lib/app/**`, `core/{visibility,storage,observability}/**`, `features/more/**`, `tool/**`, `test/architecture/**`, `test/coverage/**`, `test/helpers/**` |

**Shared string tables** (`core/l10n/app_strings.dart`, `core/l10n/locales/en/app_strings_en.dart`) belong to dev-trading. The others may add their own getter lines: read the file fresh, use one small `Edit` per getter, and never rewrite the file. Area files under `core/l10n/strings/` belong to their area owner.
**`test/coverage/all_imports_test.dart`** belongs to dev-perf. When you add files, say so in thread build; dev-perf regenerates it last.

## Done
- Analyze `--fatal-infos` is clean on your files.
- Your tests pass, and the full suite does not get worse.
- Your files are at 100% coverage.
- Your files are 300 lines or less.

Then set your task with `python3 $T task FIX-1-<you> review --owner <you> --note "<numbers>"`. Post at most 3 short messages in thread build. Keep it fast and economical: the user asked for speed and fewer tokens.
