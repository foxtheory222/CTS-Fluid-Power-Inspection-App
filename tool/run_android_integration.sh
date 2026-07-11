#!/usr/bin/env bash
set -euo pipefail

target="${1:?usage: run_android_integration.sh <integration-test-target>}"
driver="${2:-test_driver/integration_test.dart}"
log_file="$(mktemp)"
trap 'rm -f "$log_file"' EXIT

run_drive() {
  flutter drive \
    --no-dds \
    --no-pub \
    --dart-define=INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE=false \
    --driver="$driver" \
    --target="$target" \
    -d emulator-5554
}

if run_drive 2>&1 | tee "$log_file"; then
  exit 0
fi

if ! grep -Eq 'adb: device offline|device offline|device not found' "$log_file"; then
  exit 1
fi

echo "Transient Android emulator disconnect detected; restarting ADB and retrying once."
adb kill-server || true
adb start-server
adb reconnect offline || true
timeout 120 adb -s emulator-5554 wait-for-device

boot_completed=""
for _ in $(seq 1 60); do
  boot_completed="$(adb -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
  if [[ "$boot_completed" == "1" ]]; then
    break
  fi
  sleep 2
done

if [[ "$boot_completed" != "1" ]]; then
  echo "Android emulator did not recover within the bounded retry window." >&2
  exit 1
fi

run_drive

