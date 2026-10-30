#!/system/bin/sh
# Atomic guarded replacement of only the existing navbar module's 2 scripts.
set -eu
M=/data/adb/modules/s108_compact_navbar_boot
S=/data/local/tmp/s108_navbar_v10
EXPECTED=2fa01aa7dacb5eb55522f2110764354c8d3b63470301c73e471cd58707b39913
[ "$(id -u)" = 0 ] || { echo ROOT_REQUIRED; exit 20; }
[ "$(getprop ro.build.version.release)" = 13 ] || { echo WRONG_ANDROID; exit 21; }
[ "$(getprop ro.product.board)" = uws6152_1h10_go ] || { echo WRONG_BOARD; exit 22; }
[ -f "$M/module.prop" ] && grep -qx 'id=s108_compact_navbar_boot' "$M/module.prop" || { echo WRONG_MODULE; exit 23; }
[ ! -e "$M/disable" ] || { echo MODULE_DISABLED; exit 24; }
[ -e /data/adb/modules/s108_navbar_compact/disable ] || { echo OLD_NAV_NOT_DISABLED; exit 25; }
[ -f /data/adb/modules/s108_statusbar_insets/module.prop ] && [ ! -e /data/adb/modules/s108_statusbar_insets/disable ] || { echo STATUSBAR_NOT_ACTIVE; exit 26; }
[ ! -e "$M/service-v9.v10bak" ] && [ ! -e "$M/apply-v7.v10bak" ] || { echo BACKUP_EXISTS_STOP; exit 27; }
actual="$(sha256sum "$M/service.sh" | cut -d' ' -f1)"
[ "$actual" = "$EXPECTED" ] || { echo "UNEXPECTED_SERVICE_SHA=$actual"; exit 28; }
[ -s "$S/service-v10.sh" ] && [ -s "$S/apply-v10.sh" ] || { echo STAGING_MISSING; exit 29; }
# Persistent backups; leave the earlier service-v7.saved intact.
cp -p "$M/service.sh" "$M/service-v9.v10bak"
cp -p "$M/apply.sh" "$M/apply-v7.v10bak"
cp "$S/service-v10.sh" "$M/service.sh.v10new"
cp "$S/apply-v10.sh" "$M/apply.sh.v10new"
chmod 0755 "$M/service.sh.v10new" "$M/apply.sh.v10new"
chown 0:0 "$M/service.sh.v10new" "$M/apply.sh.v10new"
mv "$M/apply.sh.v10new" "$M/apply.sh"
mv "$M/service.sh.v10new" "$M/service.sh"
restorecon "$M/service.sh" "$M/apply.sh" >/dev/null 2>&1 || :
echo NAVBAR_V10_INSTALL_OK
echo SERVICE_SHA=$(sha256sum "$M/service.sh" | cut -d' ' -f1)
echo APPLY_SHA=$(sha256sum "$M/apply.sh" | cut -d' ' -f1)
echo STATUSBAR_UNTOUCHED=YES
