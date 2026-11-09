#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
if [[ "$mode" != "watchlist" ]]; then
  echo "usage: DEVICE_ID=<Pixel-6a-id> SERVER_HOST=<host-ip> bash tool/perf/frames.sh watchlist" >&2
  exit 64
fi
if [[ -z "${DEVICE_ID:-}" || -z "${SERVER_HOST:-}" ]]; then
  echo "DEVICE_ID and SERVER_HOST are required for a physical Pixel 6a run" >&2
  exit 64
fi

dart run ../market_server/bin/server.dart --clock=real &
server_pid=$!
cleanup() {
  kill "$server_pid" 2>/dev/null || true
  wait "$server_pid" 2>/dev/null || true
}
trap cleanup EXIT

for attempt in {1..30}; do
  if curl --silent --fail http://127.0.0.1:8080/health >/dev/null; then
    break
  fi
  if [[ "$attempt" == 30 ]]; then
    echo "market server did not become ready on port 8080" >&2
    exit 1
  fi
  sleep 1
done

flutter drive \
  --profile \
  --device-id "$DEVICE_ID" \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/perf/watchlist_perf_test.dart \
  --dart-define="SERVER_HOST=$SERVER_HOST"

echo "Wrote build/perf/timeline_summary.json"
