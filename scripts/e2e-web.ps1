<#
  Automated end-to-end run of the whole kiosk flow in real (headless) Chrome against the
  real mock API, at phone / tablet / desktop window sizes.

    .\scripts\e2e-web.ps1                       # all three sizes
    .\scripts\e2e-web.ps1 -Sizes '1280,800'     # just the tablet size
    .\scripts\e2e-web.ps1 -Visible              # show the browser window

  What it needs: Flutter, Node.js 18+, Google Chrome. ChromeDriver is downloaded automatically
  (matching your Chrome) into .tools/ the first time. Screenshots go to evidence/flow-<WxH>/.
  The test file is integration_test/full_flow_test.dart.
#>
param(
  [string[]]$Sizes = @('390,844', '1280,800', '1440,900'),
  [switch]$Visible
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

foreach ($tool in 'flutter', 'node', 'npx') {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "'$tool' is not on PATH." }
}

# --- Chrome version -> matching ChromeDriver ---------------------------------------------
$chromeVersion = $null
try { $chromeVersion = (Get-ItemProperty 'HKCU:\Software\Google\Chrome\BLBeacon' -ErrorAction Stop).version } catch {}
if (-not $chromeVersion) {
  foreach ($p in "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe") {
    if (Test-Path $p) { $chromeVersion = (Get-Item $p).VersionInfo.ProductVersion; break }
  }
}
if (-not $chromeVersion) { throw 'Google Chrome was not found.' }
Write-Host "Chrome $chromeVersion"

$driverDir = Join-Path $root ".tools\chromedriver\win64-$chromeVersion"
$driverExe = Get-ChildItem $driverDir -Recurse -Filter chromedriver.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $driverExe) {
  Write-Host 'Downloading ChromeDriver...'
  npx --yes '@puppeteer/browsers' install "chromedriver@$chromeVersion" --path (Join-Path $root '.tools\chromedriver') | Out-Null
  $driverExe = Get-ChildItem (Join-Path $root '.tools\chromedriver') -Recurse -Filter chromedriver.exe |
    Where-Object { $_.FullName -match [regex]::Escape($chromeVersion) } | Select-Object -First 1
  if (-not $driverExe) { throw 'ChromeDriver download failed.' }
}

# --- mock API (started here only if nothing is listening) ---------------------------------
$startedApi = $null
try { Invoke-WebRequest http://localhost:4000/health -UseBasicParsing -TimeoutSec 3 | Out-Null; Write-Host 'Mock API already running.' }
catch {
  Write-Host 'Starting mock API (grading defaults: latency + ~5% failures)...'
  $startedApi = Start-Process node -ArgumentList 'server.js' -WorkingDirectory (Join-Path $root 'mock-api') -WindowStyle Hidden -PassThru
  Start-Sleep 2
}

$driver = Start-Process $driverExe.FullName -ArgumentList '--port=4444' -WindowStyle Hidden -PassThru
Start-Sleep 2
flutter pub get | Out-Null

$failed = @()
try {
  foreach ($size in $Sizes) {
    $name = 'flow-' + ($size -replace ',', 'x')
    $dest = Join-Path $root "evidence\$name"
    if (Test-Path "$root\evidence\auto") { Remove-Item "$root\evidence\auto" -Recurse -Force }
    Write-Host "`n=== $size ===" -ForegroundColor Cyan
    $args = @('drive', '--driver=test_driver/integration_test.dart', '--target=integration_test/full_flow_test.dart',
      '-d', 'web-server', '--browser-name=chrome', "--browser-dimension=$size")
    if (-not $Visible) { $args += '--headless' }
    flutter @args
    if ($LASTEXITCODE -ne 0) { $failed += $size } else { Write-Host "PASS $size" -ForegroundColor Green }
    if (Test-Path "$root\evidence\auto") {
      if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
      Move-Item "$root\evidence\auto" $dest
    }
  }
} finally {
  Stop-Process -Id $driver.Id -Force -ErrorAction SilentlyContinue
  if ($startedApi) { Stop-Process -Id $startedApi.Id -Force -ErrorAction SilentlyContinue }
}

if ($failed.Count) { Write-Host "`nFAILED sizes: $($failed -join ' | ')" -ForegroundColor Red; exit 1 }
Write-Host "`nAll sizes passed. Screenshots: evidence\flow-*" -ForegroundColor Green
