# ADR-0009: Application layer per feature; providers declared at feature level

Status: accepted · Date: 2026-11-07 · Refs: CR-1.1, CR-1.5; HLD v2.0 §4, §4.1; TR-27, TR-28 · Supersedes: the build-brief rule "one controller per screen" (reworded below)

## Context
v1.1 has three layers per feature: `domain/`, `data/`, `presentation/`. Controllers (`WatchlistController`,
`StockDetailController`, `PortfolioController`, `SocketLabController`) sit in `presentation/` next to the widgets, and their
state classes live in the controller file. Repository providers live in `features/<f>/data/providers.dart`, and six
presentation files reach them through the `core/providers.dart` barrel. So a widget file can import a repository provider and
call the data layer directly; nothing stops it. Repositories are concrete classes; fakes `implements` the concrete class.
The user asked for "proper clean architecture with an application layer (state + controller), so presentation is pure UI"
(CR-1.5) and for providers "at feature level, not in the data layer" (CR-1.1).

## Options
1. Keep three layers; move only the provider files. Cheap, but presentation still owns controllers and state.
2. **Four layers per feature** (`domain`, `data`, `application`, `presentation`). Repository interfaces in `domain`,
   implementations in `data`, controllers and their immutable state in `application`, widgets only in `presentation`.
   Repository providers in one feature-root DI file; controller providers next to their controller. Add domain use cases
   only for meaningful business operations that benefit from an explicit boundary.
3. Option 2 plus a use-case class per operation (`GetInstrument`, `WatchQuotes`, ...), including simple pass-throughs.

## Decision
Option 2.

**Folder shape** (every feature; a layer folder exists only when it has a file):
```
features/<f>/
  <f>_providers.dart     DI: repository providers typed as the domain interface, built from data/ + core providers
  domain/                entities, value objects, pure rules, repository interfaces (abstract interface class)
  data/                  repository implementations (Live*/InMemory*), wire mapping helpers
  application/           <name>_state.dart (immutable / sealed) + <name>_controller.dart (Notifier + its provider)
  presentation/          screens, widgets, <f>_routes.dart (GoRoutes + open* helpers, ADR-0015)
```

**Where providers are declared (CR-1.1):**
| Provider kind | File | Example |
|---|---|---|
| Repository / service (DI) | `features/<f>/<f>_providers.dart` (feature root, not in `data/`) | `final marketRepositoryProvider = Provider<MarketRepository>((ref) => LiveMarketRepository(ref.watch(apiClientProvider), ref.watch(marketSocketProvider)));` |
| Controller | same file as the controller class, `application/<name>_controller.dart` | `final stockDetailControllerProvider = NotifierProvider.autoDispose.family<StockDetailController, StockDetailState, String>(StockDetailController.new);` |
| Derived read-only state shared by screens | `application/<name>_provider.dart` | `liveQuoteProvider` moves to `features/market/application/live_quote_provider.dart` |

The DI file is the only file in a feature that imports `data/`. It is the feature's composition root.

**Dependency injection flow:** core DI files (`core/<module>/<module>_providers.dart`) → feature DI file (repositories,
typed as domain interfaces) → application controllers (`ref.watch(xRepositoryProvider)` in `build`, `ref.read` in methods)
→ presentation (`ref.watch(xControllerProvider)` / `.select`, `ref.read(...notifier).command()`). Tests override the
repository provider with a fake that `implements` the domain interface, or the controller provider for widget tests.

**Import rules** (checked by `test/architecture/layer_rules_test.dart`, TR-28):
| From | May import | Must not import |
|---|---|---|
| `domain/` | own and other features' `domain/`, `core/*/domain/`, `core/error/`, `package:flutter/foundation.dart`, `option_math` | `data/`, `application/`, `presentation/`, riverpod, `http`, `dart:io`, `material`, `widgets` |
| `data/` | `domain/` (any feature), `core/*/domain/`, `core/*/data/`, `core/error/` | `application/`, `presentation/`, riverpod |
| `<f>_providers.dart` | own `data/` and `domain/`, any `core/**/<m>_providers.dart` | `application/`, `presentation/` |
| `application/` | `domain/` (any), any `*_providers.dart`, other `application/`, `core/*/application/`, riverpod, `foundation` | `data/`, `presentation/`, `material`, `widgets`, `BuildContext` |
| `presentation/` | own and other features' `application/` and `presentation/`, `domain/` (types only), `core/*/presentation/`, `core/{theme,widgets,l10n,assets,format}` | `data/`, any `*_providers.dart`, repositories |
| `core/**` | `core/**` | `features/**`, `app/**` |
| `app/` (composition root) | anything | — |

**Domain purity, pragmatic version:** entities keep their hand-written `fromJson`/`toJson`. The wire shape is the entity shape
in this app (one server, versioned protocol), so a parallel DTO per entity would double ~20 classes for no behaviour. JSON
maps are plain Dart (`Map<String, Object?>`), so the domain still has no I/O. A DTO is added the day a wire shape and an
entity diverge.

**Use cases belong in `domain/usecases/` when they express meaningful business behavior.** Keep simple controller-to-
repository calls direct; do not add one-line pass-through classes. Domain use cases may depend on domain repository
interfaces and domain rules, but must not depend on application, data, presentation, or Riverpod. Multi-repository
orchestration and business decisions with a clear name are good candidates for a use-case class.

**Controller rule (replaces "one controller per screen"):** one controller and one immutable state per screen or per
multi-step flow, by default. State shared by two or more screens gets one feature-level controller or derived provider in
`application/` (for example `positionsProvider` read by Portfolio and the stock page). A second controller for one screen
needs a written reason in the LLD (for example the ticket's submit flow, whose failure must not wipe the page). State is
`@immutable` with `==`/`hashCode`/`copyWith`; modes that exclude each other are a `sealed` family.

**Presentation is pure UI:** widgets render state, keep only visual state (text controllers, animation, scroll, expanded
tile), forward intent to a controller method, and navigate with `open*` helpers. They never call a repository, never build
an error message from a `Failure`, never call `FeedbackController`, analytics or push directly (ADR-0017, ADR-0019).
Controllers never take a `BuildContext` and never navigate; they expose state, and the widget's `ref.listen` reacts.
In-memory feature state that was modelled as a repository (`StrategyDraftRepository`) becomes an application controller.

## Consequences
- A widget cannot reach the data layer: the layer test fails the build. Controllers are tested with `ProviderContainer.test`
  and fakes, without widgets; this is what makes the 100 % coverage gate (ADR-0020) cheap.
- Six repository interfaces are added (`MarketRepository`, `ChainRepository`, `OrderRepository`, `PortfolioRepository`,
  `AlertsRepository`, `AiRepository`); implementations are renamed `Live*Repository`. Fakes in `test/helpers/` keep working
  because they already `implements` the type name.
- §10.2 names stay (the interface keeps the old class name), so LLD citations change only in the file path.
- Every controller and its state move from `presentation/` to `application/` (refactor stories, `06-lld/README.md` §6).
- Divergence from the user's `flutter-clean-riverpod-app-layer` skill: no codegen providers and JSON on entities.
  Meaningful use cases stay in `domain/usecases/`; simple repository pass-throughs remain direct controller calls.

## Who argued what
- architect: options 2 and 3 compared; option 3 rejected for pass-through classes. Options were posted in thread `architecture`.
