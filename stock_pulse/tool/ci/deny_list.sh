#!/usr/bin/env bash
# Deny-list greps for patterns the analyzer cannot express (TRD §8 step 3).
# Usage: tool/ci/deny_list.sh [repo_root] [--report-only]
# Prints every hit as `rule: file:line: text` and exits 1 on any hit, or 0
# with --report-only.
set -uo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
report_only=false
for arg in "$@"; do
  case "$arg" in
    --report-only) report_only=true ;;
    *) root="$(cd "$arg" && pwd)" ;;
  esac
done

app="$root/stock_pulse"
lib="$app/lib"
hits=0

# check <rule> <regex> <exclude-regex or ''> <paths...>
check() {
  local rule="$1" pattern="$2" exclude="$3"
  shift 3
  local found
  found="$(grep -rnE --include='*.dart' --include='*.yaml' "$pattern" "$@" 2>/dev/null || true)"
  if [[ -n "$exclude" && -n "$found" ]]; then
    found="$(grep -vE "$exclude" <<<"$found" || true)"
  fi
  [[ -z "$found" ]] && return
  while IFS= read -r line; do
    echo "$rule: ${line#"$root"/}"
    hits=$((hits + 1))
  done <<<"$found"
}

dart_dirs=("$lib" "$root/market_server/lib" "$root/packages/option_math/lib")
pubspecs=("$app/pubspec.yaml" "$root/market_server/pubspec.yaml" "$root/packages/option_math/pubspec.yaml")

check codegen "\.g\.dart|\.freezed\.dart|@riverpod|@freezed|@JsonSerializable" '' "${dart_dirs[@]}"
check codegen "build_runner|generate: true" '' "${pubspecs[@]}"
check export-barrel "^export " '' "$lib"
check colors "\bColors\." "/lib/core/theme/" "$lib"
check icons "\bIcons\." "/lib/core/assets/app_icons\.dart:" "$lib"
check asset-path "'assets/" "/lib/core/assets/app_images\.dart:" "$lib"
check text-literal "\bText\(\s*['\"]" '' "$lib"
check snackbar "showSnackBar" "/lib/core/feedback/presentation/feedback_host\.dart:" "$lib"
check route-path "(path: |\.(go|push|pushReplacement|replace)\()\s*['\"]/" "_routes\.dart:" "$lib"
check print "(^|[^A-Za-z_.])print\(" '' "${dart_dirs[@]}"
check debug-print "debugPrint\(" "/lib/core/observability/" "$lib"

echo "$hits deny-list hits"
if [[ $hits -gt 0 && $report_only == false ]]; then
  exit 1
fi
exit 0
