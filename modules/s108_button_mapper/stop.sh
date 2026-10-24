#!/system/bin/sh
MODDIR=${0%/*}
PIDFILE="$MODDIR/daemon.pid"
if [ -r "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    case "$pid" in ''|*[!0-9]*) ;; *) kill -TERM "$pid" 2>/dev/null ;; esac
fi
sleep 1
# Restore original camera gesture even if the listener already exited.
if [ -r "$MODDIR/original_camera" ]; then
    old=$(cat "$MODDIR/original_camera")
    case "$old" in
        null|'') settings delete secure camera_double_tap_power_gesture_disabled </dev/null >/dev/null 2>&1 ;;
        *) settings put secure camera_double_tap_power_gesture_disabled "$old" </dev/null >/dev/null 2>&1 ;;
    esac
fi
# Restore original rotation state when deliberately disabling/uninstalling.
oldrot=$(cat "$MODDIR/original_rotation" 2>/dev/null)
oldauto=$(cat "$MODDIR/original_autorotate" 2>/dev/null)
case "$oldrot" in 0|1|2|3) settings put system user_rotation "$oldrot" </dev/null >/dev/null 2>&1 ;; esac
case "$oldauto" in
    1) wm user-rotation free </dev/null >/dev/null 2>&1 ;;
    0) case "$oldrot" in 0|1|2|3) wm user-rotation lock "$oldrot" </dev/null >/dev/null 2>&1 ;; esac ;;
esac
echo 'S108 button mapping stopped; original camera and rotation settings restored.'
