# ADR-0021: Stricter analyzer and a hand-written lint set; best practices adopted with CR-1

Status: accepted · Date: 2026-11-07 · Refs: CR-1.10; TR-29, TR-39; `analysis_options.yaml` in all three packages

## Context
`analysis_options.yaml` is the Flutter template: `flutter_lints` and nothing else. The user asked what other best
practices we should follow (CR-1.10). `very_good_analysis` is a good list but is one more dependency whose rule set
changes under us on upgrade, and it enables `public_member_api_docs`, which contradicts ADR-0014 rule 2.

## Options
1. Keep `flutter_lints`.
2. Depend on `very_good_analysis`.
3. **`flutter_lints` (Flutter team) + strict analyzer modes + an explicit rule list written in our file.**

## Decision
Option 3. One shared rules file at the repo root, `analysis_rules.yaml`, with no package include of its own. Each
package's `analysis_options.yaml` uses the list form of `include` (Dart ≥ 3.8):
`include: [package:flutter_lints/flutter.yaml, ../analysis_rules.yaml]` in `stock_pulse`, and
`include: [package:lints/recommended.yaml, ../analysis_rules.yaml]` (`../../` for `option_math`) in the Dart packages.

```yaml
# analysis_rules.yaml
analyzer:
  language: { strict-casts: true, strict-inference: true, strict-raw-types: true }
  errors: { unawaited_futures: error, discarded_futures: error, always_use_package_imports: error,
            avoid_dynamic_calls: error, cancel_subscriptions: error, close_sinks: error }
linter:
  rules:
    - always_use_package_imports          # ADR-0013
    - directives_ordering
    - avoid_dynamic_calls                 # no dynamic; JSON is Map<String, Object?> with pattern matching
    - strict_top_level_inference
    - type_annotate_public_apis
    - always_declare_return_types
    - prefer_final_locals
    - prefer_final_fields
    - prefer_const_constructors
    - prefer_const_declarations
    - unnecessary_lambdas
    - unawaited_futures
    - discarded_futures
    - cancel_subscriptions
    - close_sinks
    - avoid_catches_without_on_clauses    # catch a type; data layer maps to AppError
    - only_throw_errors
    - no_default_cases                    # exhaustive switch on sealed / enum (ADR-0014 rule 6)
    - avoid_positional_boolean_parameters
    - avoid_redundant_argument_values
    - unnecessary_await_in_return
    - use_super_parameters
    - prefer_single_quotes
    - avoid_print
    - comment_references
    - test_types_in_equals
    - unnecessary_statements
    - use_colored_box
    - use_decorated_box
    - sized_box_shrink_expand
```
CI runs `flutter analyze --fatal-infos` and `dart format --output=none --set-exit-if-changed .`.

**Practices adopted (each enforced where a tool can):**
| Practice | Enforced by |
|---|---|
| Four layers + import rules; core never imports features | `test/architecture/layer_rules_test.dart` (TR-28) |
| No code generation, no `part` files, no `export` barrels in `lib/` | CI grep (NFR-18, ADR-0011) |
| No `dynamic`; JSON as `Map<String, Object?>` read with patterns (`if (json case {'id': String id})`) | `avoid_dynamic_calls`, strict modes |
| States and outcomes are `sealed` where modes exclude each other; `switch` without `default` | `no_default_cases`, review |
| Immutable state: `final` fields, `List.unmodifiable` / `Map.unmodifiable` on construction, `listEquals` in `==` | review, controller tests |
| Riverpod: `ref.watch` in `build`, `ref.read` in methods, `ref.mounted` after every `await`, `autoDispose` unless app-wide, no `BuildContext` in notifiers | `flutter-architecture-review` checklist |
| Async: no un-awaited futures without `unawaited(...)`; every `StreamSubscription` cancelled in `ref.onDispose` / `dispose` | `unawaited_futures`, `discarded_futures`, `cancel_subscriptions` |
| Errors: data layer catches typed exceptions and returns `Failure(AppError)`; nothing else catches broadly | `avoid_catches_without_on_clauses` |
| Logging only through `CrashReporter.log`; no `print` | `avoid_print`, grep `debugPrint` |
| `const` widgets and `select` on hot paths (NFR-4/5) | `prefer_const_constructors`, build-counter tests |
| 300-line files, coding rules (ADR-0014); 100 % coverage (ADR-0020) | CI scripts |
| Every new dependency has an ADR and a TRD §1.1 row | review |
| Accessibility: semantics labels on icon-only buttons, 48 dp targets, text scale 2.0 golden (NFR-12/13) | widget tests, `accessibility-tester` |

## Consequences
- The first `flutter analyze` after R-0 reports many findings in wave 0/1 code; `dart fix --apply` fixes most
  (imports, const, finals, super parameters); the rest are fixed by each owner in their refactor story.
- One file for three packages keeps the rules identical; a package-specific exception needs a comment and the
  architect's approval.
