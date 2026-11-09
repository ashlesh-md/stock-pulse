#!/usr/bin/env bash
set -eo pipefail

strict_args=()
dropdown_args=()
if [ "${STRICT_QUALITY:-0}" = "1" ]; then
  strict_args=(--strict)
  dropdown_args=(--strict)
elif [ "${STRICT_NO_DROPDOWN:-0}" = "1" ]; then
  dropdown_args=(--strict)
fi

dart tool/ci/string_literal_check.dart "${strict_args[@]}"
dart tool/ci/asset_registry_check.dart "${strict_args[@]}"
dart tool/ci/formatter_check.dart "${strict_args[@]}"
dart tool/ci/no_dropdown_check.dart "${dropdown_args[@]}"
dart tool/ci/brand_check.dart
dart tool/ci/analytics_catalog_check.dart
