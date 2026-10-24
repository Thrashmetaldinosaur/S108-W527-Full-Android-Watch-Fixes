#!/system/bin/sh
# S108 crDroid A13, manual-only verified 28dp left / 16dp right status bar.
# Requires root. Boot-time persistence is not yet reliable.
TARGET=com.android.systemui
L=com.android.shell:s108_clock_hex
R=com.android.shell:s108_icons_balanced16
cmd overlay disable --user 0 com.android.shell:s108_icons_hex >/dev/null 2>&1 || :
if ! cmd overlay list --user 0 "$TARGET" | grep -Fq "$L"; then
  cmd overlay fabricate --target "$TARGET" --name s108_clock_hex "$TARGET:dimen/status_bar_padding_start" 0x05 0x1C01 || exit 1
fi
if ! cmd overlay list --user 0 "$TARGET" | grep -Fq "$R"; then
  cmd overlay fabricate --target "$TARGET" --name s108_icons_balanced16 "$TARGET:dimen/status_bar_padding_end" 0x05 0x1001 || exit 1
fi
cmd overlay enable --user 0 "$L" || exit 1
cmd overlay enable --user 0 "$R" || exit 1
A=$(cmd overlay lookup --user 0 "$TARGET" "$TARGET:dimen/status_bar_padding_start")
B=$(cmd overlay lookup --user 0 "$TARGET" "$TARGET:dimen/status_bar_padding_end")
echo "STATUS Left=$A Right=$B"
case "$A" in *28.0dip*) ;; *) exit 2 ;; esac
case "$B" in *16.0dip*) ;; *) exit 3 ;; esac
killall com.android.systemui >/dev/null 2>&1 || :
