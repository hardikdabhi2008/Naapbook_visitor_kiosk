#!/usr/bin/env bash
# Starts the mock Visitor API (mock-api/server.js, unchanged) on http://localhost:4000.
#   ./scripts/start-api.sh          grading defaults: 300-1500 ms latency, ~5% HTTP 500
#   ./scripts/start-api.sh --fast   local development only: no latency, no failures
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
command -v node >/dev/null || { echo "Node.js 18+ is required (https://nodejs.org)"; exit 1; }
if [ "${1:-}" = "--fast" ]; then export MOCK_LATENCY=off MOCK_FAILURE_RATE=0; fi
cd "$root/mock-api"
exec node server.js
