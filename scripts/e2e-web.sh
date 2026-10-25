#!/usr/bin/env bash
# Automated end-to-end run of the whole kiosk flow in real headless Chrome against the real
# mock API, at phone / tablet / desktop window sizes (macOS / Linux).
#   ./scripts/e2e-web.sh                 all three sizes
#   ./scripts/e2e-web.sh 1280,800        just one size
# Needs Flutter, Node.js 18+, Google Chrome. ChromeDriver is downloaded into .tools/ on first run.
# NOTE: written for macOS/Linux but only verified on Windows (use e2e-web.ps1 there).
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
sizes=("$@"); [ ${#sizes[@]} -eq 0 ] && sizes=(390,844 1280,800 1440,900)

for t in flutter node npx; do command -v "$t" >/dev/null || { echo "'$t' is not on PATH"; exit 1; }; done

chrome="${CHROME_BIN:-}"
for c in "google-chrome" "google-chrome-stable" "chromium" "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
  [ -n "$chrome" ] && break
  if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then chrome="$c"; fi
done
[ -n "$chrome" ] || { echo "Google Chrome not found (set CHROME_BIN)"; exit 1; }
version="$("$chrome" --version | grep -Eo '[0-9]+(\.[0-9]+){3}' | head -1)"
echo "Chrome $version"

npx --yes @puppeteer/browsers install "chromedriver@$version" --path "$root/.tools/chromedriver" >/dev/null
driver="$(find "$root/.tools/chromedriver" -type f -name chromedriver -path "*$version*" | head -1)"
[ -n "$driver" ] || { echo "ChromeDriver download failed"; exit 1; }

started_api=""
if ! curl -fs http://localhost:4000/health >/dev/null; then
  echo "Starting mock API (grading defaults)..."
  (cd "$root/mock-api" && node server.js >/dev/null 2>&1 & echo $! > "$root/.tools/api.pid")
  started_api="$(cat "$root/.tools/api.pid")"; sleep 2
fi
"$driver" --port=4444 >/dev/null 2>&1 & driver_pid=$!
trap '[ -n "$started_api" ] && kill "$started_api" 2>/dev/null; kill "$driver_pid" 2>/dev/null' EXIT
sleep 2
flutter pub get >/dev/null

failed=()
for size in "${sizes[@]}"; do
  name="flow-${size/,/x}"
  rm -rf evidence/auto
  echo; echo "=== $size ==="
  if flutter drive --driver=test_driver/integration_test.dart --target=integration_test/full_flow_test.dart \
       -d web-server --browser-name=chrome "--browser-dimension=$size" --headless; then
    echo "PASS $size"
  else
    failed+=("$size")
  fi
  if [ -d evidence/auto ]; then rm -rf "evidence/$name"; mv evidence/auto "evidence/$name"; fi
done
if [ ${#failed[@]} -gt 0 ]; then echo; echo "FAILED sizes: ${failed[*]}"; exit 1; fi
echo; echo "All sizes passed. Screenshots: evidence/flow-*"
