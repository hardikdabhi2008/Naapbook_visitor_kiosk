<#
  Runs / tests / profiles the app on a connected Android phone or tablet (USB debugging on)
  or a running emulator.

    .\scripts\run-android.ps1                 # run the app (debug)
    .\scripts\run-android.ps1 -Mode test      # run the automated full flow ON the device
    .\scripts\run-android.ps1 -Mode profile   # profile-mode run for DevTools frame charts
    .\scripts\run-android.ps1 -Device <id>    # pick one when several are attached

  The device reaches the mock API on your PC through `adb reverse tcp:4000 tcp:4000`, so no
  Wi-Fi / firewall / IP setup is needed (works for emulators and USB devices alike).
#>
param(
  [ValidateSet('run', 'test', 'profile')][string]$Mode = 'run',
  [string]$Device
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

# --- locate adb ---------------------------------------------------------------------------
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
  foreach ($base in $env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, "$env:LOCALAPPDATA\Android\Sdk") {
    if ($base -and (Test-Path "$base\platform-tools\adb.exe")) { $adb = "$base\platform-tools\adb.exe"; break }
  }
}
if (-not $adb) { throw 'adb not found. Install Android Studio or the platform-tools and retry.' }

# --- pick a device --------------------------------------------------------------------------
$devices = & $adb devices | Select-Object -Skip 1 | Where-Object { $_ -match '\tdevice$' } | ForEach-Object { ($_ -split '\t')[0] }
if (-not $devices) {
  throw 'No Android device found. Plug it in (data cable), enable Developer options > USB debugging, accept the prompt on the phone, then check `adb devices`.'
}
if (-not $Device) { $Device = $devices | Select-Object -First 1 }
Write-Host "Device: $Device"

# --- mock API must be up on the PC -----------------------------------------------------------
try { Invoke-WebRequest http://localhost:4000/health -UseBasicParsing -TimeoutSec 3 | Out-Null }
catch { throw 'Mock API is not running. In another terminal: .\scripts\start-api.ps1' }

& $adb -s $Device reverse tcp:4000 tcp:4000 | Out-Null
$define = '--dart-define=API_BASE_URL=http://localhost:4000'

switch ($Mode) {
  'run'     { flutter run -d $Device $define }
  'profile' { flutter run --profile -d $Device $define }
  'test'    { flutter test integration_test/full_flow_test.dart -d $Device $define }
}
