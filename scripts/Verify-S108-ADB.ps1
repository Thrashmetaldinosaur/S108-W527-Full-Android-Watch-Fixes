# Read-only Windows PowerShell verification for an XTQ S108 after USB ADB authorization.
# Run with: .\Verify-S108-ADB.ps1
param([string]$Adb = 'adb')
$ErrorActionPreference = 'Stop'
if (-not (Get-Command $Adb -ErrorAction SilentlyContinue)) {
    throw 'adb not found. Run in Android platform-tools folder or supply -Adb "C:\path\to\adb.exe"'
}
$devices = @(& $Adb devices | Select-String '^([^\s]+)\s+device$')
if ($devices.Count -ne 1) {
    & $Adb devices -l
    throw 'Expected exactly one authorized ADB device. Supply a single connected S108 before continuing.'
}
$serial = $devices[0].Matches[0].Groups[1].Value
$model = (& $Adb -s $serial shell getprop ro.product.model | Out-String).Trim()
$hardware = (& $Adb -s $serial shell getprop ro.hardware | Out-String).Trim()
Write-Host "Target serial: $serial" -ForegroundColor Cyan
Write-Host "Android model: $model; hardware: $hardware"
$confirm = Read-Host 'Confirm this is your S108 (type YES)'
if ($confirm -cne 'YES') { Write-Host 'Cancelled'; return }
Write-Host '=== Android ===' -ForegroundColor Cyan
foreach ($p in @('ro.product.model','ro.product.device','ro.hardware','ro.build.version.release','ro.build.version.sdk','sys.usb.state','init.svc.adbd')) {
  $val = (& $Adb -s $serial shell getprop $p | Out-String).Trim()
  Write-Host "${p}: $val"
}
Write-Host '=== Persistent developer settings ===' -ForegroundColor Cyan
foreach ($k in @('development_settings_enabled','adb_enabled')) {
  $val = (& $Adb -s $serial shell settings get global $k | Out-String).Trim()
  Write-Host "${k}: $val"
}
Write-Host '=== Settings activity overrides (user 0) ===' -ForegroundColor Cyan
$dump = & $Adb -s $serial shell dumpsys package com.android.settings
$from = @($dump | Select-String 'User 0:' | Select-Object -Last 1)
if ($from.Count) {
  $userDump = ($dump -join "`n") -split 'User 0:', 2
  if ($userDump.Count -gt 1) {
    $userDump[1] -split "`n" | Select-String 'disabledComponents:|enabledComponents:|DevelopmentSettingsDashboardActivity' -Context 0,2
  }
} else {
  $dump | Select-String 'disabledComponents:|enabledComponents:|DevelopmentSettingsDashboardActivity' -Context 0,2
}
Write-Host 'Read-only verification completed. No settings changed.' -ForegroundColor Green
