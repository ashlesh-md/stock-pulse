# ADR-0016: Deep links (custom scheme + https app links) and a `PushService` placeholder for FCM / APNs

Status: accepted · Date: 2026-11-07 · Refs: CR-1.15; ADR-0015; TR-33; PRD v1.4 FRs (deep links, push: product-manager)

## Context
CR-1.15 asks for deep links and for placeholders for FCM / APNs push. There is no backend that sends pushes and no
Firebase project, so push must be an interface with a no-op implementation that a real one can replace without touching
screens. Deep links must open the same screens as in-app navigation, through go_router (ADR-0015).

## Options
1. Add `firebase_messaging` now, disabled. Brings a Firebase project, `google-services.json`, iOS pods and startup cost
   (NFR-1) for a feature that does nothing yet.
2. **Interface + no-op now; platform config as commented placeholders; the real FCM/APNs adapter is a later story.**
3. `app_links` / `uni_links` packages for links. Not needed: Flutter's built-in deep linking hands the URI to the router.

## Decision
Option 2.

**Link formats** (both map to the same go_router paths):
| Kind | Example | Notes |
|---|---|---|
| Custom scheme | `stockpulse://app/stock/RELIANCE`, `stockpulse://app/options?u=NIFTY&e=2026-11-10`, `stockpulse://app/trade/RELIANCE?side=buy&type=limit&price=1500` | host is always `app`; read-only paths map to router paths; trade maps to the guarded ticket |
| App link / universal link | `https://stockpulse.example.com/stock/RELIANCE`, `https://stockpulse.example.com/trade/RELIANCE?side=buy&type=market` | domain is a placeholder until a real one exists |

Flutter's deep linking (`flutter_deeplinking_enabled`, on by default) gives the URI to `GoRouter`. A custom-scheme URI is
normalised in `app/router/deep_link.dart`; `GoRouter` accepts `/watchlist`, `/options`, `/ai`, `/portfolio`,
`/stock/:id`, `/alerts` and the limited `/trade/:id` prefill. Developer screens, `/risk-notice` and `/strategy` are
refused (→ `/watchlist`). Trade links require a valid buy/sell side and market or limit type; limit links require a
finite positive limit price. They resolve to the ordinary order ticket, retaining the risk disclosure and stale-price
block. No link can submit, confirm, modify or cancel an order, or create an alert. Unknown or refused links show one
localized "Link not available" message and return to the watchlist.

**Platform config placeholders** (dev-perf owns; values marked `TODO(release)`):
- Android `AndroidManifest.xml`, main activity: an `intent-filter` (`VIEW`, `DEFAULT`, `BROWSABLE`) for scheme `stockpulse`,
  host `app`; a second `intent-filter android:autoVerify="true"` for `https`, host `stockpulse.example.com`, path prefixes
  `/stock`, `/trade`, `/options`, `/portfolio`, `/alerts`, `/ai`, `/watchlist`. `docs/deeplinks/assetlinks.json` template
  (package name, SHA-256 placeholder).
- iOS: `CFBundleURLTypes` with `stockpulse` in `Info.plist`; `Runner.entitlements` with
  `com.apple.developer.associated-domains` = `applinks:stockpulse.example.com`; `docs/deeplinks/apple-app-site-association`
  template (team id placeholder).
- Test: `adb shell am start -a android.intent.action.VIEW -d "stockpulse://app/stock/RELIANCE"` and
  `xcrun simctl openurl booted "stockpulse://app/stock/RELIANCE"`, written into the QA plan.

**Push** (`core/push/`, layered per ADR-0010):
```dart
// domain
@immutable class PushMessage { final String id; final String? title, body; final Uri? link; final Map<String, String> data; }
abstract interface class PushService {
  Future<void> init();                       // ask permission when a real impl exists; no-op now
  Future<String?> token();                   // FCM / APNs token for the server; null in no-op
  Future<PushMessage?> initialMessage();     // the tap that cold-started the app
  Stream<PushMessage> get onTap;             // taps while running / backgrounded
  Stream<PushMessage> get onForeground;      // received while the app is open
}
// data
final class NoopPushService implements PushService { ... }   // returns null / empty streams
// push_providers.dart
final pushServiceProvider = Provider<PushService>((ref) => const NoopPushService());
```
`FakePushService` in `test/helpers/` emits messages on demand.

**How a tap routes:** `app/push_link_handler.dart` (`PushLinkHandler`, created with the router in `app/router/`) reads
`initialMessage()` once after the first frame and listens to `onTap`. For each message with a `link`, it applies
`normaliseLink` and `DeepLinkPolicy`, then calls `router.go(path)`. So a push is a deep link that arrives by another road;
there is one policy for both. `onForeground` goes to `FeedbackController.show(...)` as an info message with a "View"
action that does the same `go`. `init()` is called after the first frame, never in `main()` (TR-14).

**Adding FCM / APNs later** = one new class `FcmPushService implements PushService` in `core/push/data/`, the
`firebase_messaging` dependency (with an ADR for it), the platform files, and one line in `push_providers.dart`. No
screen, router or controller changes.

## Consequences
- Zero startup cost now; push and link handling is fully testable with fakes (`router.state.uri` assertions).
- The domain `stockpulse.example.com` and the team/package ids are placeholders; app-link verification will fail until a
  real domain hosts the two files. Custom-scheme links work today.
- One more policy list to keep in step with the route table; the router test checks every allowed path resolves.
