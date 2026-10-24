#!/system/bin/sh
# S108 crDroid A13, manual-only verified compact navigation.
# Requires root. Boot-time persistence is NOT guaranteed.
set -u
ensure() {
  target="$1"; name="$2"; res="$3"; data="$4"
  if ! cmd overlay list --user 0 "$target" 2>/dev/null | grep -Fq "com.android.shell:$name"; then
    cmd overlay fabricate --target "$target" --name "$name" "$res" 0x05 "$data" || return 1
  fi
  cmd overlay enable --user 0 "com.android.shell:$name" || return 1
}
ensure android s108compact_height android:dimen/navigation_bar_height 0x2401 || exit 1
ensure android s108compact_frame android:dimen/navigation_bar_frame_height 0x2401 || exit 1
ensure com.android.systemui s108compact_keys com.android.systemui:dimen/navigation_key_width 0x3C01 || exit 1
H=$(cmd overlay lookup --user 0 android android:dimen/navigation_bar_height)
W=$(cmd overlay lookup --user 0 com.android.systemui com.android.systemui:dimen/navigation_key_width)
echo "NAVBAR Height=$H KeyWidth=$W"
case "$H" in *36.0dip*) ;; *) exit 2 ;; esac
case "$W" in *60.0dip*) ;; *) exit 3 ;; esac
killall com.android.systemui >/dev/null 2>&1 || :
