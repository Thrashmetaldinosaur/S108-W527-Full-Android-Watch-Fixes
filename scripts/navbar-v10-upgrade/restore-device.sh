#!/system/bin/sh
# Manual rollback: never called by installer; root only.
set -eu
M=/data/adb/modules/s108_compact_navbar_boot
[ "$(id -u)" = 0 ] || exit 20
[ -s "$M/service-v9.v10bak" ] && [ -s "$M/apply-v7.v10bak" ] || { echo NO_V10_BACKUPS; exit 21; }
cp -p "$M/service-v9.v10bak" "$M/service.sh.restore"
cp -p "$M/apply-v7.v10bak" "$M/apply.sh.restore"
mv "$M/apply.sh.restore" "$M/apply.sh"
mv "$M/service.sh.restore" "$M/service.sh"
echo V9_AND_V7_SCRIPTS_RESTORED_NO_REBOOT
