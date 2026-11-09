# 09 · Change request CR-1 (from the user, 7 Nov 2026, during wave 1)

Status: open · Owner: engineering manager · Applies to: PRD, UX, design system, TRD/HLD/ADRs, LLDs, stories, and all code written so far.

The user's points, numbered as given. Each has an owner who turns it into requirements, decisions or design.

| # | User's request | Owner(s) | Lands in |
|---|---|---|---|
| CR-1.0 | **Charts like Kite.** Kite has many chart features and advanced chart and stock features; add that kind of feature set. | product-manager (scope), ui-designer + ux-designer (design), dev-ai/dev-trading (build) | PRD v1.4 FRs, UX/design specs, stories |
| CR-1.0b | **Replace Flutter's default dropdown** (it looks poor) with a designed picker component. | ui-designer, dev-trading | design system, trading LLD |
| CR-1.1 | **Providers live at feature level**, not in the data layer. | architect | HLD v2, ADR, all LLDs |
| CR-1.2 | **One snackbar at a time.** Repeated bad taps must not stack snackbars; show only one. | ux-designer, architect | UX spec, HLD (a single feedback service) |
| CR-1.3 | **Human-like code.** Remove unwanted comments and AI-looking code. | all developers, reviewer | coding rules in build brief, review checklist |
| CR-1.4 | **No file over 300 lines.** | architect (rule + CI check), all developers | TRD, CI check, LLDs |
| CR-1.5 | **Proper clean architecture with an application layer** (state + controller), so presentation is pure UI. | architect | HLD v2, ADR, all LLDs |
| CR-1.6 | **Imports**: decide package vs relative imports; prefer package imports unless there is a reason not to. | architect | ADR, lint rule |
| CR-1.7 | **Better names for `Ok` / `Err`** in `Result`. | architect | ADR, `core/error` |
| CR-1.8 | **Core can be layered too** (core features with their own domain/data/application layers where needed). | architect | HLD v2 folder layout |
| CR-1.9 | **`stock_pulse/lib/core/providers.dart`**: is it needed? Justify it or remove it. | architect | ADR |
| CR-1.10 | **Best practices**: look for more that should be followed. | architect, reviewer | TRD/ADRs |
| CR-1.11 | **Strings, images and icons in one customisable place**, ready for more languages later (localisation). | architect, ux-designer | ADR (l10n with ARB, no codegen beyond Flutter's own gen_l10n decision), design system |
| CR-1.12 | **Good app icon and splash**, and near-zero startup time. | ui-designer (icon, splash), dev-perf | design system, perf LLD |
| CR-1.13 | **Check every failure case.** | qa-lead, all developers | test plan, LLD failure tables |
| CR-1.14 | **Scalability, extensibility and testability first; 100% coverage and proper TDD.** | architect (coverage gate and exclusions), qa-lead | TRD, CI |
| CR-1.15 | **go_router**, with **deep links**, and **placeholders for FCM / APNs** push. | architect, product-manager | ADR (replaces the earlier no-go_router decision), PRD FRs |
| CR-1.16 | **Generic analytics** with placeholders: adding any analytics tool must be easy. | architect, product-manager | ADR, PRD FR |

## Process

1. Developers finish only the story they were in the middle of, keep it green, and stop.
2. Product manager: PRD v1.4 with new FRs for CR-1.0, 1.0b, 1.11, 1.12, 1.15, 1.16 (and failure cases, 1.13), after studying what Kite's chart offers.
3. Architect: HLD v2, ADRs and TRD updates for CR-1.1 to 1.11, 1.14 to 1.16, including an answer to CR-1.9.
4. Designers: chart toolbar and tools, the picker component, single-snackbar rules, app icon and splash.
5. Developers update their LLDs; the scrum master updates stories (including refactor stories for wave 0 and 1 code).
6. Build continues under the new rules.
