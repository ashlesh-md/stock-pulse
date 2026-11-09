# ADR-0017: Generic analytics: `AnalyticsService` fans out to pluggable sinks, logged from the application layer

Status: accepted · Date: 2026-11-07 · Refs: CR-1.16; TR-34; PRD v1.4 analytics FR (product-manager names the events)

## Context
The user wants analytics placeholders such that adding any analytics tool (Firebase, Mixpanel, Amplitude, an in-house
endpoint) is easy (CR-1.16). There is no vendor today. Events must not leak into widgets, and an analytics failure must
never break a screen or an order.

## Options
1. Call a vendor SDK from widgets. Vendor lock-in, untestable, against ADR-0009.
2. **One `AnalyticsService` with an event model; a list of `AnalyticsSink`s behind it; a debug sink now.**
3. A third-party abstraction package (for example `analytics` wrappers). One more dependency for ~80 lines of ours.

## Decision
Option 2. Module `core/analytics/` (layered, ADR-0010). Owner: dev-perf.

```dart
// domain/analytics_event.dart
@immutable
final class AnalyticsEvent {
  const AnalyticsEvent(this.name, [this.params = const {}]);
  final String name;                         // snake_case, ≤ 40 chars, [a-z0-9_]
  final Map<String, Object> params;          // String | int | double | bool only, ≤ 25 entries
}
// domain/analytics_events.dart: the catalogue, one factory per event, so names live in one file
abstract final class Events {
  static AnalyticsEvent screenView(String screen) => AnalyticsEvent('screen_view', {'screen': screen});
  static AnalyticsEvent orderSubmitted({required String kind, required String product, required String source}) => ...;
  static AnalyticsEvent orderOutcome({required String status, required int latencyMs}) => ...;
  static AnalyticsEvent alertCreated({required String condition}) => ...;
  static AnalyticsEvent aiQuestionAsked({required String intent}) => ...;
  static AnalyticsEvent deepLinkOpened({required String path, required String via}) => ...;   // via: link | push
}
// domain/analytics_sink.dart
abstract interface class AnalyticsSink {
  String get id;                                           // 'debug', 'firebase', ...
  Future<void> log(AnalyticsEvent event);
  Future<void> setUserProperty(String name, String? value);
  Future<void> reset();                                    // on Reset demo (FR-112)
}
// data/debug_analytics_sink.dart: ring of the last 200 events for the debug overlay; no I/O
// application/analytics_service.dart
final class AnalyticsService {
  AnalyticsService(this._sinks, this._reporter, {required bool Function() consent});
  void log(AnalyticsEvent event);   // fire-and-forget: validates in debug (assert), drops when !consent(),
                                    // calls every sink, catches and reports each sink error to CrashReporter
}
// analytics_providers.dart
final analyticsSinksProvider = Provider<List<AnalyticsSink>>((ref) => [if (kDebugMode) DebugAnalyticsSink()]);
final analyticsProvider = Provider<AnalyticsService>(...);   // consent from LocalPrefsData.analyticsConsent
```

**Consent:** `LocalPrefsData.analyticsConsent` (bool, default `false` in release, `true` in debug builds so the debug sink
shows events) with a Settings switch (More, dev-perf). Off → `log` is a no-op and `reset()` runs on every sink. No PII is
ever an event parameter: no names, no account ids, no free text from chat (the AI intent label only).

**Who logs:**
- Business events: application controllers, `ref.read(analyticsProvider).log(Events.orderSubmitted(...))`, at the point the
  action is decided (ticket controller on submit and on outcome, alerts controller on create, chat controller on ask).
- Screen views: `AnalyticsScreenObserver` (root navigator, in `GoRouter(observers:)`) plus the shell scaffold on branch
  change, both logging `Events.screenView(ScreenId.x.name)`. No widget logs an event.
- Deep links and pushes: `PushLinkHandler` / router `onEnter` log `deepLinkOpened`.

**Adding a vendor** = one class `FirebaseAnalyticsSink implements AnalyticsSink` (or Mixpanel, ...) in `core/analytics/data/`,
its dependency with an ADR, and one entry in `analyticsSinksProvider`. Several vendors at once work by listing several sinks.

## Consequences
- Analytics is testable with `FakeAnalyticsSink` (records events): controller tests assert the exact events.
- `log` never awaits on the caller's path; a slow or throwing sink cannot delay an order or crash a screen.
- The event catalogue is a single file, so the PM and QA can review names; renaming an event is a code review, not a
  dashboard surprise.
