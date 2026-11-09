# ADR-0010: Core modules are layered when they hold state or I/O; utilities stay flat

Status: accepted · Date: 2026-11-07 · Refs: CR-1.8; ADR-0009; HLD v2.0 §4.2

## Context
`core/` today is a flat set of folders: `network/` holds the socket, wire messages, REST client, backoff and providers side by
side; `lifecycle/`, `storage/`, `observability/` mix interfaces, file implementations and Riverpod state. `core/navigation/`
imports `features/market/presentation` (openers) and `features/orders/domain` (args), so core depends on features.
The user asked whether core can be layered like a feature (CR-1.8).

## Options
1. Keep core flat.
2. Layer every core folder (`domain/data/application/presentation`), including `format/` and `theme/`.
3. **Layer a core module only when it has an interface with I/O implementations or state that screens watch; keep pure
   utilities and presentation kits flat.** Core never imports features.

## Decision
Option 3. Same layer names and import rules as ADR-0009; each layered module has a root DI file `<module>_providers.dart`.

| Module | Shape | Contents (v2.0) |
|---|---|---|
| `core/network/` | layered | `domain/` (`SocketMessage` family, `SocketStatus`, `NetworkStatus`, `FeedMode`, subscription types) · `data/` (`MarketSocket`, `ApiClient`, `api_client_lines.dart`, `DebugClient`, `Backoff`, `ResyncCoordinator`) · `application/` (`socketStatusProvider`, `networkStatusProvider`) · `network_providers.dart` (`appConfigProvider`, `apiClientProvider`, `marketSocketProvider`, `debugClientProvider`) |
| `core/market_time/` | layered | `domain/` (`Clock`, `MarketPhase`, `MarketClockState`, `freshnessOf`, `ServerClock`) · `data/` (`ClockRepository`) · `application/` (`marketClockProvider`, `freshnessTickProvider`) · `market_time_providers.dart` (`clockProvider`, `serverClockProvider`, `clockRepositoryProvider`) |
| `core/storage/` | layered | `domain/` (`AppSnapshot`, `LocalPrefsData`, `SnapshotStore`, `LocalPrefs` interfaces) · `data/` (`AtomicJsonFile`, `FileSnapshotStore`, `FileLocalPrefs`) · `application/` (`SnapshotScheduler`, `snapshotProvider`, `localPrefsProvider`) · `storage_providers.dart` |
| `core/observability/` | layered | `domain/` (`CrashReporter`) · `data/` (`DebugCrashReporter`, `PerfMarks`, `PaintProbe`) · `observability_providers.dart` |
| `core/platform/` | layered | `domain/` (`Haptics`, `HapticDedupe`) · `data/` (`MethodChannelHaptics`, `NoopHaptics`) · `platform_providers.dart` |
| `core/visibility/` (was `lifecycle/`) | layered | `domain/` (`ScreenId`, `CoveredState`) · `application/` (`selectedTabProvider`, `coveredStateProvider`, `screenVisibleProvider`) · `presentation/` (`VisibilityRouteObserver`) |
| `core/analytics/` | layered | ADR-0017 |
| `core/push/` | layered | ADR-0016 |
| `core/feedback/` | layered | ADR-0019 |
| `core/error/`, `core/config/`, `core/format/` | flat | `Result`, `AppError` · `AppConfig` · formatters |
| `core/theme/`, `core/widgets/`, `core/l10n/`, `core/assets/` | flat (presentation kits) | tokens and extensions · shared widgets · `AppStrings` · `AppImages`, `AppIcons` |
| `core/navigation/` | **deleted** | args move to the owning feature's `domain/`; openers become each feature's `presentation/<f>_routes.dart`; the route table is `app/router/` (ADR-0015) |

`lib/app/` is the composition root: `app.dart`, `bootstrap.dart`, `router/`, app-level hosts (`OrderOutcomeListener`,
`AlertBannerHost`, `FeedbackHost` mount, `PushLinkHandler`). It may import anything; nothing imports it except `main.dart`.

## Consequences
- The "core never imports features" rule becomes checkable (TR-28) and true: the two current violations
  (`openers.dart`, `args.dart`) disappear with `core/navigation/`.
- A module is either flat or layered, never both, so a reader knows where a file is.
- Files move but keep their class names; `dart fix` plus IDE moves do most of it. Owners move their own modules
  (`06-lld/README.md` §6).
- `VisibilityRouteObserver` is presentation (it extends a widgets-layer `NavigatorObserver`); the providers it feeds are
  application, so controllers never import Flutter widgets.
