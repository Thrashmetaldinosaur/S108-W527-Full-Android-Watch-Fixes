#!/system/bin/sh
# S108 v10 existing Magisk module service: Binder-safe FD handling.
# No new modules; affects navbar fabricated overlays only.
MODDIR=${0%/*}
LOG="$MODDIR/boot-v10.log"
: > "$LOG"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }
log "NAVBAR_V10_SERVICE_START uid=$(id -u) context=$(id -Z 2>/dev/null)"
tries=0
while [ "$(getprop sys.boot_completed)" != '1' ]; do
    tries=$((tries+1))
    if [ "$tries" -ge 120 ]; then log 'ERROR_BOOT_NEVER_COMPLETED'; exit 1; fi
    sleep 2
done
log 'BOOT_COMPLETE; first attempt in 20 seconds'
sleep 20
n=0
while [ "$n" -lt 5 ]; do
    n=$((n+1))
    log "APPLY_ATTEMPT=$n"
    # Magisk's BusyBox shell is appropriate; no nested su needed.
    # Each Binder-facing cmd in apply-v10.sh redirects stdin/out/err to /dev/null.
    result="$(/system/bin/sh "$MODDIR/apply.sh" 2>&1)"
    rc=$?
    log "APPLY_EXIT=$rc $result"
    if [ "$rc" -eq 0 ]; then
        log 'NAVBAR_APPLY_OK; refreshing SystemUI once'
        killall com.android.systemui >/dev/null 2>&1 || :
        log 'NAVBAR_V10_SERVICE_SUCCESS; exiting'
        exit 0
    fi
    [ "$n" -lt 5 ] && sleep 20
done
log 'NAVBAR_V10_SERVICE_FAILED; no persistent retry daemon'
exit 1
