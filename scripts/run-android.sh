#!/usr/bin/env bash
# Runs / tests / profiles the app on a connected Android phone or tablet (USB debugging on)
# or a running emulator (macOS / Linux).
#   ./scripts/run-android.sh            run the app (debug)
#   ./scripts/run-android.sh test       run the automated full flow ON the device
#   ./scripts/run-android.sh profile    profile-mode run for DevTools frame charts
#   DEVICE=<id> ./scripts/run-android.sh ...   pick one when several are attached
# The device reaches the mock API on your computer through `adb reverse tcp:4000 tcp:4000`.
# NOTE: written for macOS/Linux but only verified on Windows (use run-android.ps1 there).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
mode="${1:-run}"

adb_bin="$(command -v adb || true)"
for base in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk" "$HOME/Library/Android/sdk"; do
  [ -z "$adb_bin" ] && [ -n "$base" ] && [ -x "$base/platform-tools/adb" ] && adb_bin="$base/platform-tools/adb"
done
[ -n "$adb_bin" ] || { echo "adb not found. Install Android Studio / platform-tools."; exit 1; }

device="${DEVICE:-$("$adb_bin" devices | awk 'NR>1 && $2=="device" {print $1; exit}')}"
[ -n "$device" ] || { echo "No Android device. Plug it in, enable USB debugging, accept the prompt, check 'adb devices'."; exit 1; }
echo "Device: $device"

curl -fs http://localhost:4000/health >/dev/null || { echo "Mock API is not running. In another terminal: ./scripts/start-api.sh"; exit 1; }
"$adb_bin" -s "$device" reverse tcp:4000 tcp:4000 >/dev/null
define="--dart-define=API_BASE_URL=http://localhost:4000"

case "$mode" in
  run)     flutter run -d "$device" "$define" ;;
  profile) flutter run --profile -d "$device" "$define" ;;
  test)    flutter test integration_test/full_flow_test.dart -d "$device" "$define" ;;
  *) echo "usage: $0 [run|test|profile]"; exit 1 ;;
esac
