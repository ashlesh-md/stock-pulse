# ADR-0008: `ThemeExtension`s replace `MarketColors`

Status: accepted · Date: 2026-11-06 · Refs: TR-19; NFR-12; 03b-design-system v1.4 §2, §8, review item 290

## Context
v1 has a static `MarketColors` class (`core/widgets/market_colors.dart`) used by `TickPrice` and `QuoteTile`, and a seeded
`ColorScheme`. The design system adds light and dark themes, and the v1 light up/down colours fail AA (2.69:1 and 3.45:1).

## Options
1. Keep static `MarketColors` and add a light variant switch.
2. **`SpColors` and `SpTypography` as `ThemeExtension`s** (with `lerp`, `copyWith`, `const dark`/`light`), explicit `ColorScheme`, spacing/radius/density as `abstract final class` consts.
3. A custom `InheritedWidget` theme.

## Decision
Option 2, accessed via `context.sp` / `context.spText`. All numeric styles bake in `FontFeature.tabularFigures()`.
Migration: add theme → replace `TickPrice` with `SpPriceCell` (tint from tick time, no timer) → swap `QuoteTile` colours to
`context.sp.directionOf` → fix `ConnectionBadge` → delete `market_colors.dart` → CI grep: no `MarketColors`, no `Colors.`
outside `core/theme`. Goldens in both themes at 1.0× and 2.0×.

## Consequences
- Theme switching (system + Settings) and AA-compliant light tokens for free with `Theme.of`.
- Spacing stays const (no lookup cost, never themed).
- Every widget reads one extension; tests must wrap in `AppTheme`.

## Who argued what
- dev-trading: proposed option 2 and the migration steps.
- ui-designer (03b v1.4): mapped tokens to `SpColors`/`SpTypography` and flagged the AA failure.
- No one argued for option 1 or 3.
