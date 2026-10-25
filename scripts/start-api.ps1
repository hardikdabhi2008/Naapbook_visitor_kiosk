<#
  Starts the mock Visitor API (mock-api/server.js, unchanged) on http://localhost:4000.
    .\scripts\start-api.ps1          # grading defaults: 300-1500 ms latency, ~5% HTTP 500
    .\scripts\start-api.ps1 -Fast    # local development only: no latency, no failures
#>
param([switch]$Fast)

$root = Split-Path $PSScriptRoot -Parent
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Error "Node.js 18+ is required (https://nodejs.org). Then re-run this script."; exit 1
}
if ($Fast) { $env:MOCK_LATENCY = 'off'; $env:MOCK_FAILURE_RATE = '0' }
Set-Location (Join-Path $root 'mock-api')
node server.js
