# ADR-0018: Hand-written `AppStrings` per locale (not gen_l10n); one registry for images and icons

Status: accepted · Date: 2026-11-07 · Refs: CR-1.11; NFR-18 (no code generation); TR-31, TR-36

## Context
Strings, images and icons are scattered as literals in widgets (`Text('Socket Lab')`, `Icons.cable`). The user wants them
in one customisable place, ready for more languages later (CR-1.11). Flutter's own answer is gen_l10n: ARB files plus
`flutter: generate: true`, which writes `AppLocalizations` Dart classes at `flutter pub get` / build time. The project
rule is no code generation (NFR-18; the user's reason: generated code they did not write is hard to read and debug).

**Is gen_l10n code generation?** Yes. It is not build_runner and needs no annotations, but it writes Dart source the team
did not write (one class per locale plus a lookup), and that source is what runs. It also produces files over 300 lines
(ADR-0014) and would need exclusions from the file-length and coverage gates (ADR-0020). So it falls under the rule.

## Options
1. gen_l10n with ARB (`l10n.yaml`, `generate: true`). Translator-friendly ARB, ICU plurals, but generated code.
2. **Hand-written: an `AppStrings` interface split by area, one implementation per locale, a hand-written
   `LocalizationsDelegate`.** Compile-time completeness: a new locale that misses a string does not compile.
3. A `Map<String, String>` per locale looked up by key. Not type-safe; a typo is a runtime blank.

## Decision
Option 2, with the plural/number rules from `intl` (already a dependency) and `flutter_localizations` (Flutter SDK, no
codegen) for Material and Cupertino widget strings.

```
core/l10n/
  app_strings.dart            abstract interface class AppStrings { CommonStrings get common; MarketStrings get market;
                              OptionsStrings get options; OrderStrings get orders; PortfolioStrings get portfolio;
                              AlertStrings get alerts; AiStrings get ai; MoreStrings get more; ErrorStrings get errors; }
                              AppStrings appStringsFor(Locale locale)   // falls back to en
  strings/<area>_strings.dart abstract interface class MarketStrings { String get watchlistTitle;
                              String addedToWatchlist(String symbol); String holdingsCount(int n); ... }
  locales/en/<area>_strings_en.dart   final class MarketStringsEn implements MarketStrings { const MarketStringsEn(); ... }
  locales/en/app_strings_en.dart      const AppStringsEn() composing the areas
  app_strings_delegate.dart   LocalizationsDelegate<AppStrings>: load(locale) => SynchronousFuture(appStringsFor(locale))
  l10n_context.dart           extension L10nX on BuildContext { AppStrings get strings; }
  plural.dart                 String plural(int n, {required String one, required String other, String? zero}) via Intl.plural
  l10n_providers.dart         localeProvider (Notifier<Locale>, device locale or Settings), stringsProvider (Provider<AppStrings>)
```
- Widgets read `context.strings.market.watchlistTitle`. The application layer, which has no `BuildContext`, reads
  `ref.read(stringsProvider)` when it builds a `FeedbackMessage` or a user-facing state field. Both come from
  `appStringsFor(locale)`, so they never disagree.
- Supported locales v2.0: `en_IN`. Adding Hindi = `locales/hi/*_hi.dart` implementing each area + one line in
  `appStringsFor` + `supportedLocales`. A translator can work from a spreadsheet export; if a translation vendor needs ARB
  later, we revisit this ADR (switching to gen_l10n is mechanical because the area interfaces already name every string).
- Each area file stays under 300 lines; an area that grows splits (for example `OrderStrings` → `TicketStrings`,
  `OrderListStrings`).
- `AppError.message` is never shown; `ErrorStrings` maps error kinds to text (`errors.network`, `errors.server(code)`).

**Assets and icons, one place each:**
- `core/assets/app_images.dart`: `abstract final class AppImages { static const logo = 'assets/images/logo.png'; ... }`.
  Files under `stock_pulse/assets/images/` with `2.0x/` and `3.0x/` variants; `pubspec.yaml` declares the folders.
- `core/assets/app_icons.dart`: `abstract final class AppIcons { static const watchlist = Icons.show_chart_rounded; ... }`,
  semantic names mapped to Material icons (or a custom icon font later, changed in this file only).
- App launcher icon and native splash are platform resources (Android adaptive icon + `SplashScreen` theme, iOS
  `AppIcon` set + `LaunchScreen.storyboard`), drawn by ui-designer and committed as files; no generator package.

**CI greps (TR-36):** no `Icons.` outside `core/assets/app_icons.dart`; no `'assets/` literal outside
`core/assets/app_images.dart`; no `Text('` / `Text("` with a literal under `lib/features/**/presentation/` and
`lib/core/widgets/`; a test checks every `AppImages` path exists on disk.

## Consequences
- Every user-visible string moves once (each owner moves their own, refactor stories). After that a new screen cannot add a
  literal (grep).
- No generated files, so no exclusions in the file-length gate; `lib/core/l10n/locales/**` (pure string tables) is the one
  data exclusion in the coverage gate (ADR-0020); the interfaces, delegate, `plural` and `appStringsFor` are covered.
- No ICU message syntax for translators; plurals use `plural(...)` in code. Acceptable for one language now.
