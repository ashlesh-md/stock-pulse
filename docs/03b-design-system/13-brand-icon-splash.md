# 03b Part 13: App icon and splash (v2.0)

Owner: ui-designer. Implementer of PNG generation: dev-perf. Requirements: PRD FR-170 to FR-172.

## 13.1 Concept

A **pulse line rising through a candle**: one neutral candle (off-white, never green or red) in the centre, crossed by an accent-blue pulse line that has a small heartbeat dip and climbs to the upper right. It says "market" (candle) and "live" (pulse) in two shapes. Accent `#5AA9FF` on dark `#0E1116`; the background is plain and neutral so no up/down meaning leaks into the brand. Strokes are 54 to 60 units on a 1024 grid, so the line is about 2.7 px at 48 px and stays readable; there are 3 shapes only.

## 13.2 Source files (hand-written SVG, 1024 x 1024 viewBox)

| File | Use |
|---|---|
| `stock_pulse/assets/brand/app_icon.svg` | Full icon master: iOS (no alpha), Android legacy and Play Store, web/macOS |
| `stock_pulse/assets/brand/app_icon_foreground.svg` | Android adaptive foreground. 108 dp layer; all shapes and strokes inside the 66 dp safe circle (radius 313 units around 512,512). Transparent |
| `stock_pulse/assets/brand/app_icon_monochrome.svg` | Android 13 themed icon layer (single colour, transparent; the system tints it) |
| `stock_pulse/assets/brand/splash_logo.svg` | Splash mark, transparent, no background |

Adaptive background layer is a flat colour `#0E1116` (`ic_launcher_background` colour resource); no separate SVG.

## 13.3 Splash spec

| | Light | Dark |
|---|---|---|
| Background | `#FFFFFF` (= `surface0` light) | `#0E1116` (= `surface0` dark) |
| Candle | `#8A95A5` (3.0:1 on white, graphic) | `#8A95A5` (6.2:1) |
| Pulse line | `#0B5CAD` (6.67:1) | `#5AA9FF` (7.70:1) |

- **Logo size:** 160 dp square on iOS and on Android below 12 (the mark, centred, 0 dp offset). Android 12+: icon canvas is 288 dp with a 192 dp circle mask; the mark is drawn so the pulse and candle sit inside the circle (the SVG already fits the 66/108 safe zone, which maps inside 192/288).
- **No-flash rule (hard requirement):** the native splash background equals `surface0` of the theme the first Flutter frame will use, and the first Flutter frame is the plain `surface0` scaffold with no second logo. So the user sees: native splash, then identical background, then content. No Flutter-drawn splash route, no fade, no artificial delay (FR-171). If the stored theme setting disagrees with the system (user forced dark in light OS), the first frame still uses the system theme until the first read; the app reads the stored theme synchronously before `runApp` (a single `SharedPreferences` value already loaded) so the dark choice shows before frame 1, and the splash cannot be changed per app setting (accepted, documented).
- **Android 12+ (SplashScreen API):** `values-v31/styles.xml` and `values-night-v31/styles.xml` set `windowSplashScreenBackground` to the background above, `windowSplashScreenAnimatedIcon` to the mark (vector or 288 dp PNG layer), no `windowSplashScreenBrandingImage`, no `windowSplashScreenAnimationDuration` beyond default; the Android 13 monochrome layer is separate. Pre-12: `LaunchTheme` windowBackground layer-list of the colour plus the centred 160 dp bitmap, `values` and `values-night`.
- **iOS:** `LaunchScreen.storyboard` with a full-bleed colour view using named colours `LaunchBackground` (light/dark variants in `Assets.xcassets`) and a centred 160 pt image view `LaunchLogo` (light and dark variants), constraints centre X/Y, no text. Remove the default Flutter `LaunchImage`.
- Splash removes at first frame (`FlutterNativeSplash`-style removal is not needed; the platform removes it when Flutter draws).

## 13.4 PNG generation (dev-perf)

Render the SVG with a deterministic rasteriser (`rsvg-convert`, `inkscape --export-type=png`, or `resvg`; one tool, pinned version, script at `tool/brand/generate_icons.sh`). Rules: sRGB, 8-bit, no interlace, trimmed metadata. iOS icons have **no alpha channel** (flatten on `#0E1116`). Android foreground and monochrome keep alpha. Output a `generated` summary hash file so CI can verify the PNGs match the SVGs.

### Android (res)

| Resource | Source | Sizes (px) |
|---|---|---|
| `mipmap-mdpi/ic_launcher.png` | app_icon.svg | 48 |
| `mipmap-hdpi` | app_icon.svg | 72 |
| `mipmap-xhdpi` | app_icon.svg | 96 |
| `mipmap-xxhdpi` | app_icon.svg | 144 |
| `mipmap-xxxhdpi` | app_icon.svg | 192 |
| `mipmap-*/ic_launcher_foreground.png` | app_icon_foreground.svg | 108, 162, 216, 324, 432 (mdpi to xxxhdpi) |
| `mipmap-*/ic_launcher_monochrome.png` | app_icon_monochrome.svg | 108, 162, 216, 324, 432 |
| `mipmap-anydpi-v26/ic_launcher.xml` | hand XML | adaptive: background colour, foreground, monochrome |
| Play Store listing icon | app_icon.svg | 512 (outside the repo build, in `store/`) |

### iOS (`AppIcon.appiconset`)

| Idiom | Points x scale | Pixels |
|---|---|---|
| iPhone notification | 20 x2, 20 x3 | 40, 60 |
| iPhone settings | 29 x2, 29 x3 | 58, 87 |
| iPhone spotlight | 40 x2, 40 x3 | 80, 120 |
| iPhone app | 60 x2, 60 x3 | 120, 180 |
| iPad notification | 20 x1, 20 x2 | 20, 40 |
| iPad settings | 29 x1, 29 x2 | 29, 58 |
| iPad spotlight | 40 x1, 40 x2 | 40, 80 |
| iPad app | 76 x1, 76 x2 | 76, 152 |
| iPad Pro app | 83.5 x2 | 167 |
| App Store | 1024 x1 | 1024 |

### Splash images

| Platform | File | Sizes (px) |
|---|---|---|
| iOS `LaunchLogo` light | splash_logo.svg with light line `#0B5CAD` | 160 (1x), 320 (2x), 480 (3x) |
| iOS `LaunchLogo` dark | splash_logo.svg with dark line `#5AA9FF` | 160, 320, 480 |
| Android below 12 `drawable` and `drawable-night` | same | mdpi 160, hdpi 240, xhdpi 320, xxhdpi 480, xxxhdpi 640 |
| Android 12+ animated icon | vector drawable (convert the SVG to an Android VectorDrawable) or PNG 288 dp at xxxhdpi 1152 | 1152 |

The splash_logo.svg source uses the dark line colour; the generator replaces the `stroke="#5AA9FF"` value with `#0B5CAD` for the light set.

### Acceptance (QA)

Launcher icon visible and not clipped on a circle, squircle and square mask; themed icon works on Android 13+; iOS asset catalog builds with no alpha warning; splash colours match `surface0` of the system theme and nothing flashes between splash and first frame (video or slow-motion check on a release build).
