#!/system/bin/sh
# Magisk late_start service: start the listener without blocking boot.
MODDIR=${0%/*}
[ -e "$MODDIR/disable" ] && exit 0
(
    i=0
    while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 90 ]; do
        sleep 2
        i=$((i+1))
    done
    [ "$(getprop sys.boot_completed)" = "1" ] || exit 0
    sleep 2
    /system/bin/sh "$MODDIR/button_daemon.sh" >> "$MODDIR/button.log" 2>&1 </dev/null
) >/dev/null 2>&1 &
exit 0
