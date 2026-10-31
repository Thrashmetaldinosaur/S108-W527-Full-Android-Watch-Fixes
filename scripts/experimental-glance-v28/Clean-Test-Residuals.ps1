# Optional one-time cleanup for the *exact* V28 October 30 test run.
# V28 clock->sleep functionality passed 2/2; its only warning was an
# unprivileged attempt to remove root-owned diagnostic files.
# Does not touch Magisk modules, DA217 registers, firmware, Android apps,
# keylayouts or any other test run's files.
param(
  [string]$Adb = "$HOME\Downloads\PC\platform-tools\adb.exe",
  [string]$Serial = "192.168.88.3:40215"
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Adb)) { throw "ADB not found: $Adb" }
$Target = '/data/local/tmp/s108_glance_v28_ccac571ad4df'
$Board = (& $Adb -s $Serial shell getprop ro.product.board).Trim()
if ($LASTEXITCODE -ne 0 -or $Board -ne 'uws6152_1h10_go') { throw 'Wrong/offline device; nothing deleted.' }
$Root = (& $Adb -s $Serial shell su -c 'id -u').Trim()
if ($LASTEXITCODE -ne 0 -or $Root -ne '0') { throw 'Root preflight failed; nothing deleted.' }
$IrqPath = '/sys/devices/virtual/xr-gsensor/device/irq1enable'
$Irq = (& $Adb -s $Serial shell su -c "cat $IrqPath").Trim()
if ($LASTEXITCODE -ne 0 -or $Irq -ne '0') { throw 'IRQ state is not confirmed 0; nothing deleted.' }
& $Adb -s $Serial shell su -c "/system/bin/rm -rf $Target"
if ($LASTEXITCODE -ne 0) { throw 'Failed to remove exact V28 test directory.' }
$Check = (& $Adb -s $Serial shell su -c "test ! -e $Target && echo REMOVED").Trim()
if ($LASTEXITCODE -ne 0 -or $Check -ne 'REMOVED') { throw 'Could not verify test directory removal.' }
$IrqFinal = (& $Adb -s $Serial shell su -c "cat $IrqPath").Trim()
if ($LASTEXITCODE -ne 0 -or $IrqFinal -ne '0') { throw 'Final IRQ check failed.' }
Write-Host "CLEANUP_OK=1 FINAL_IRQ1ENABLE=$IrqFinal" -ForegroundColor Green
