# 03b Part 14: Assets, icons and strings registry (v2.0)

Owner: ui-designer. Rules from PRD FR-160 to FR-164.

## 14.1 One registry for images and icons

- `AppAssets` (images, brand, illustrations) and `AppIcons` (every icon) are the only places that name a path or an `IconData`. No `'assets/...'` string and no `Icons.*` outside them (CI grep, FR-163). Swapping an icon is a one-line change in `AppIcons`.
- `AppIcons` returns `IconData` (Material Symbols Rounded outline, weight 400, 24 dp; 20 dp in dense rows, see 7). Filled variants only for the selected nav item. Direction arrows stay the text glyphs `▲ ▼`.
- Folder layout:

| Folder | Content | Format |
|---|---|---|
| `assets/brand/` | app icon, splash, wordmark | SVG sources (generated PNGs go to platform folders, part 13) |
| `assets/images/` | empty-state illustrations, onboarding | SVG preferred, PNG 3x only if needed |
| `assets/fonts/` | bundled fonts (tabular figures) | TTF/OTF |

### Naming rules
- Files: `snake_case`, lower case, ASCII, `<area>_<subject>[_<variant>].<ext>`: `empty_watchlist.svg`, `brand_wordmark_dark.svg`. No spaces, no dates, no `final`.
- Raster density suffix via folders (`2.0x/`, `3.0x/`), never in the filename.
- Dart constants: `lowerCamelCase` mirror of the file name: `AppAssets.emptyWatchlist`. Icons: by meaning, not by shape: `AppIcons.studies`, `AppIcons.expand`, `AppIcons.draw`, not `AppIcons.pencil`.
- Every asset is registered in `pubspec.yaml` by folder; unused assets are removed in the same change.
- Decorative images get `excludeFromSemantics: true`; informative images get a semantic label from ARB.

## 14.2 Strings

- **Every user-facing string goes through the localisation layer** (ARB files, `app_en.arb` now; PRD FR-160): labels, hints, button text, error messages, semantics labels, tooltips, snackbar and banner copy, and the picker option labels. No string literal in presentation code. Exempt: symbols, numbers, debug-only Socket Lab frames.
- ICU placeholders and plurals, never concatenation (FR-161): `lots` as one plural key. Numbers, rupee amounts, dates and times come from the single formatter (FR-162), never ad-hoc `NumberFormat`.
- Key naming: `<area><Subject><Role>` in lowerCamelCase: `chartStudiesLimitMessage`, `pickerIntervalLabel`, `bannerPricesNotLive` (placeholder `{time}`).
- Copy rules: sentence case, no trailing full stop on labels, plain words, a message says what happened and what to do. Keep fixed strings from the PRD verbatim (`Price not live since hh:mm:ss`, `Simulated. Not advice.`).
- Layout must survive +40% text (pseudo-locale, FR-164) and 200% scale: pickers, chips and banners use min heights and wrap instead of clip.
