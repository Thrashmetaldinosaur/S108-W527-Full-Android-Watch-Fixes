#!/system/bin/sh
# S108 V28 verified experimental root-side clock dismissal -> virtual POWER key.
# Device-tested 2026-10-30: timeout and tap both slept display.
# NOT a persistent service; NO DA217 IRQ enablement.
set -u
BASE="$1"
TRIAL="$2"
TOKEN="$3"
EXPECT="$4"
BIN="$5"
OUT="$BASE/out/$TRIAL"
mkdir -p "$OUT" || exit 40
STATUS="$OUT/controller.status"
STREAM="$OUT/event-stream.log"
ERR="$OUT/logcat-error.txt"
if [ "$(id -u)" != 0 ];then echo 'RESULT=NOT_ROOT' > "$STATUS";exit 41;fi
if ! command -v timeout >/dev/null 2>&1;then echo 'RESULT=NO_TIMEOUT' > "$STATUS";exit 42;fi
if [ "$TRIAL" = selftest ];then
  printf 'ROOT_SELFTEST_OK=1\nUID=0\n' > "$STATUS"
  exit 0
fi
case "$EXPECT" in SELFTEST|TAP|TIMEOUT) : ;; *) echo 'RESULT=BAD_EVENT' > "$STATUS";exit 44;; esac
printf 'ARM_READY=1\nTOKEN=%s\nEXPECT=%s\nUID=0\n' "$TOKEN" "$EXPECT" > "$STATUS"
: > "$STREAM"
: > "$ERR"
timeout 19 /system/bin/logcat -T 1 -v brief -s 'S108Glance:I' '*:S' 2> "$ERR" |
while IFS= read -r line;do
  printf '%s\n' "$line" >> "$STREAM"
  case "$line" in
    *"V28_ARM_$TOKEN"*)
      echo 'MARKER_SEEN=1' >> "$STATUS"
      if [ "$EXPECT" = SELFTEST ];then
        echo 'RESULT=STREAM_OK' >> "$STATUS"
        exit 0
      fi
      ;;
    *"DISMISS_$EXPECT"*)
      if /system/bin/grep -Fq 'MARKER_SEEN=1' "$STATUS";then
        echo 'EVENT_MATCHED=1' >> "$STATUS"
        # Avoid KEY_POWER toggling a display that is already off.
        if ! /system/bin/dumpsys power | /system/bin/grep -Eq 'mWakefulness[[:space:]]*=[[:space:]]*Awake';then
          echo 'RESULT=NOT_AWAKE_SKIP_POWER' >> "$STATUS";exit 0
        fi
        "$BIN" > "$OUT/uinput-command.txt" 2>&1
        rc=$?
        printf 'UINPUT_RC=%s\n' "$rc" >> "$STATUS"
        if [ "$rc" -eq 0 ] && /system/bin/grep -Fq 'POWER_KEY_EMITTED' "$OUT/uinput-command.txt";then
          echo 'RESULT=POWER_KEY_SENT' >> "$STATUS"
        else echo 'RESULT=UINPUT_FAILED' >> "$STATUS";fi
        exit 0
      fi
      ;;
  esac
done
if ! /system/bin/grep -Eq '^RESULT=' "$STATUS";then
  if /system/bin/grep -Fq 'MARKER_SEEN=1' "$STATUS";then echo 'RESULT=EVENT_TIMEOUT' >> "$STATUS";
  else echo 'RESULT=MARKER_TIMEOUT' >> "$STATUS";fi
fi
exit 0
