#!/system/bin/sh
M=/data/adb/modules/s108_compact_navbar_boot
printf 'ROOT_UID=%s\n' "$(id -u)"
for id in s108_compact_navbar_boot s108_navbar_compact s108_statusbar_insets; do
    p="/data/adb/modules/$id"
    [ -f "$p/module.prop" ] || { echo "MODULE_${id}=MISSING"; continue; }
    if [ -e "$p/disable" ]; then state=DISABLED; else state=ENABLED; fi
    echo "MODULE_${id}=$state"
done
for f in service.sh apply.sh service-v9.v10bak apply-v7.v10bak; do
    if [ -f "$M/$f" ]; then sha256sum "$M/$f"; else echo "MISSING=$f"; fi
done
echo ===SERVICE_BOOT_V10===
if [ -f "$M/boot-v10.log" ]; then tail -100 "$M/boot-v10.log"; else echo NO_BOOT_V10_LOG; fi
echo ===LAST_STATUSBAR_LOG===
P=/data/adb/modules/s108_statusbar_insets/statusbar-boot.log
if [ -f "$P" ]; then tail -12 "$P"; else echo NO_STATUSBAR_LOG; fi
