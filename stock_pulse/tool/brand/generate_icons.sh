#!/usr/bin/env bash
# Renders every launcher icon and splash PNG from assets/brand/*.svg and writes
# tool/brand/generated.sha256. Run from stock_pulse/ on macOS.
# Rasteriser: AppKit via tool/brand/render_svg.swift, pinned to the Swift and
# macOS versions below so the PNG bytes stay identical between runs.
set -euo pipefail

PINNED_SWIFT="Apple Swift version 6.2 "
PINNED_MACOS="26."

swift_version="$(swift --version 2>&1 | head -1)"
macos_version="$(sw_vers -productVersion)"
if [[ "$swift_version" != *"$PINNED_SWIFT"* || "$macos_version" != "$PINNED_MACOS"* ]]; then
  echo "generate_icons: needs Swift ${PINNED_SWIFT}on macOS ${PINNED_MACOS}x (have: $swift_version, macOS $macos_version)" >&2
  exit 1
fi

brand=assets/brand
res=android/app/src/main/res
appicon=ios/Runner/Assets.xcassets/AppIcon.appiconset
logo=ios/Runner/Assets.xcassets/LaunchLogo.imageset

jobs() {
  local density icon layer splash
  for spec in mdpi:48:108:160 hdpi:72:162:240 xhdpi:96:216:320 xxhdpi:144:324:480 xxxhdpi:192:432:640; do
    IFS=: read -r density icon layer splash <<<"$spec"
    echo "$brand/app_icon.svg $res/mipmap-$density/ic_launcher.png $icon opaque"
    echo "$brand/app_icon_foreground.svg $res/mipmap-$density/ic_launcher_foreground.png $layer alpha"
    echo "$brand/app_icon_monochrome.svg $res/mipmap-$density/ic_launcher_monochrome.png $layer alpha"
    echo "$brand/splash_logo.svg $res/drawable-$density/splash_logo.png $splash alpha"
    echo "$brand/splash_logo.svg $res/drawable-$density/splash_logo_light.png $splash light"
  done
  echo "$brand/splash_logo.svg $res/drawable-xxxhdpi/splash_icon.png 1152 alpha"
  echo "$brand/splash_logo.svg $res/drawable-xxxhdpi/splash_icon_light.png 1152 light"
  for spec in 20:1 20:2 20:3 29:1 29:2 29:3 40:1 40:2 40:3 60:2 60:3 76:1 76:2 83.5:2 1024:1; do
    local points="${spec%%:*}" scale="${spec##*:}"
    local pixels
    pixels="$(awk "BEGIN { printf \"%d\", $points * $scale }")"
    echo "$brand/app_icon.svg $appicon/Icon-App-${points}x${points}@${scale}x.png $pixels opaque"
  done
  for scale in 1 2 3; do
    local suffix=""
    [[ $scale -gt 1 ]] && suffix="@${scale}x"
    echo "$brand/splash_logo.svg $logo/LaunchLogo$suffix.png $((160 * scale)) light"
    echo "$brand/splash_logo.svg $logo/LaunchLogoDark$suffix.png $((160 * scale)) alpha"
  done
  echo "$brand/app_icon.svg store/play_store_icon.png 512 opaque"
}

jobs | swift tool/brand/render_svg.swift

{
  shasum -a 256 "$brand"/*.svg
  jobs | awk '{ print $2 }' | sort -u | xargs shasum -a 256
} >tool/brand/generated.sha256
echo "generate_icons: $(jobs | wc -l | tr -d ' ') PNGs, hashes in tool/brand/generated.sha256"
