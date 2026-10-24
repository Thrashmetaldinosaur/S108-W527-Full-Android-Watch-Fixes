#!/system/bin/sh
# S108/W527 crDroid Android 13 - persistent implementation of verified v2 test.
# KEY_F9: short BACK, hold VOLUME_UP, double rotate 0/90 degrees.
# KEY_POWER: stock short and hold untouched; double WAKE+HOME.
# Read-only getevent. Does NOT grab input or change kernel/key layouts.
set +e
MODDIR=${0%/*}
BASE=/data/local/tmp/s108_button_mapper
FIFO="$BASE/events"
SEQFILE="$BASE/seq"
PIDFILE="$MODDIR/daemon.pid"
EVPID=""

[ -e "$MODDIR/disable" ] && exit 0
if [ -r "$PIDFILE" ]; then
    oldpid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$oldpid" ] && kill -0 "$oldpid" 2>/dev/null; then
        echo "Another button listener is already running: $oldpid"
        exit 0
    fi
fi

mkdir -p "$BASE" || exit 1
rm -f "$FIFO"
mkfifo "$FIFO" || exit 1
echo 0 > "$SEQFILE"

# Find gpio-keys by NAME instead of assuming /dev/input/event7 is stable.
INPUTDEV=$(getevent -il 2>/dev/null | awk '/^add device [0-9]+:/ {dev=$NF} /name:.*"gpio-keys"/ {print dev; exit}')
if [ -z "$INPUTDEV" ] || [ ! -r "$INPUTDEV" ]; then
    echo 'S108 ERROR: gpio-keys input device missing.'
    rm -f "$FIFO"
    exit 1
fi

# Preserve original preferences ONCE so disable/uninstall restores them.
if [ ! -e "$MODDIR/original_camera" ]; then
    settings get secure camera_double_tap_power_gesture_disabled </dev/null > "$MODDIR/original_camera" 2>/dev/null
fi
if [ ! -e "$MODDIR/original_rotation" ]; then
    settings get system user_rotation </dev/null > "$MODDIR/original_rotation" 2>/dev/null
fi
if [ ! -e "$MODDIR/original_autorotate" ]; then
    settings get system accelerometer_rotation </dev/null > "$MODDIR/original_autorotate" 2>/dev/null
fi

# All Binder service commands must NOT inherit the event FIFO as stdin.
run_service() { "$@" </dev/null >/dev/null 2>&1; return $?; }

cleanup() {
    trap - EXIT HUP INT TERM
    [ -n "$EVPID" ] && kill "$EVPID" 2>/dev/null
    rm -f "$FIFO" "$SEQFILE" "$PIDFILE"
    # Restore camera shortcut on STOP. Rotation is restored by stop.sh.
    old=$(cat "$MODDIR/original_camera" 2>/dev/null)
    case "$old" in
        null|'') settings delete secure camera_double_tap_power_gesture_disabled </dev/null >/dev/null 2>&1 ;;
        *) settings put secure camera_double_tap_power_gesture_disabled "$old" </dev/null >/dev/null 2>&1 ;;
    esac
    echo 'S108 button mapper stopped; original camera setting restored.'
}
trap cleanup EXIT
trap 'exit 0' HUP INT TERM

echo $$ > "$PIDFILE"
settings put secure camera_double_tap_power_gesture_disabled 1 </dev/null >/dev/null 2>&1 || exit 1

rotation_state=$(settings get system user_rotation </dev/null 2>/dev/null)
case "$rotation_state" in 0|1|2|3) ;; *) rotation_state=0 ;; esac
left_down=0
left_last_up=0
left_double=0
left_seq=0
power_down=0
power_last_up=0
power_double=0

echo "S108 button mapper START: gpio-keys=$INPUTDEV; pid=$$"
getevent -lt "$INPUTDEV" > "$FIFO" 2>/dev/null &
EVPID=$!
while IFS= read -r line; do
    [ -e "$MODDIR/disable" ] && break
    case "$line" in
        *EV_KEY*KEY_F9*DOWN*|*EV_KEY*KEY_F9*UP*|*EV_KEY*KEY_POWER*DOWN*|*EV_KEY*KEY_POWER*UP*) ;;
        *) continue ;;
    esac
    now=$(printf '%s\n' "$line" | awk -F'[][]' '{print int(($2+0)*1000)}')
    case "$now" in ''|*[!0-9]*) continue ;; esac
    case "$line" in
        *EV_KEY*KEY_F9*DOWN*)
            left_down=$now
            left_double=0
            if [ "$left_last_up" -gt 0 ] && [ $((now-left_last_up)) -le 420 ]; then
                left_double=1
                left_seq=$((left_seq+1))
                echo "$left_seq" > "$SEQFILE"
            fi
            ;;
        *EV_KEY*KEY_F9*UP*)
            [ "$left_down" -gt 0 ] || continue
            held=$((now-left_down))
            left_down=0
            if [ "$held" -ge 650 ]; then
                left_seq=$((left_seq+1))
                echo "$left_seq" > "$SEQFILE"
                left_last_up=0
                left_double=0
                if run_service input keyevent 24; then
                    echo 'LEFT HOLD -> Volume slider (+1): OK'
                else
                    echo 'LEFT HOLD -> Volume: FAILED'
                fi
            elif [ "$left_double" -eq 1 ]; then
                left_last_up=0
                left_double=0
                case "$rotation_state" in 1) next=0 ;; *) next=1 ;; esac
                if run_service wm user-rotation lock "$next"; then
                    echo "LEFT DOUBLE -> Rotation $rotation_state -> $next: OK"
                    rotation_state=$next
                else
                    echo 'LEFT DOUBLE -> Rotation: FAILED'
                fi
            else
                left_last_up=$now
                left_seq=$((left_seq+1))
                myseq=$left_seq
                echo "$myseq" > "$SEQFILE"
                (
                    sleep 0.46
                    currentseq=$(cat "$SEQFILE" 2>/dev/null)
                    if [ "$currentseq" = "$myseq" ]; then
                        if run_service input keyevent 4; then
                            echo 'LEFT SINGLE -> Back: OK'
                        else
                            echo 'LEFT SINGLE -> Back: FAILED'
                        fi
                    fi
                ) &
            fi
            ;;
        *EV_KEY*KEY_POWER*DOWN*)
            power_down=$now
            power_double=0
            if [ "$power_last_up" -gt 0 ] && [ $((now-power_last_up)) -le 450 ]; then
                power_double=1
            fi
            ;;
        *EV_KEY*KEY_POWER*UP*)
            [ "$power_down" -gt 0 ] || continue
            held=$((now-power_down))
            power_down=0
            if [ "$held" -gt 650 ]; then
                power_last_up=0
                power_double=0
                echo 'RIGHT HOLD -> original power handling preserved'
            elif [ "$power_double" -eq 1 ]; then
                power_last_up=0
                power_double=0
                if run_service input keyevent 224; then
                    echo 'RIGHT DOUBLE -> Wake: OK'
                else
                    echo 'RIGHT DOUBLE -> Wake: FAILED'
                fi
                if run_service input keyevent 3; then
                    echo 'RIGHT DOUBLE -> Home: OK'
                else
                    echo 'RIGHT DOUBLE -> Home: FAILED'
                fi
            else
                power_last_up=$now
            fi
            ;;
    esac
done < "$FIFO"
