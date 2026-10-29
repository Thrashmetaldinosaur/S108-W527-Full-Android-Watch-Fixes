#!/system/bin/sh
# S108 / Android13: only navbar resources. Crucial: Binder-facing cmd
# must inherit /dev/null, NOT a Magisk-owned logfile or Magisk's console.
# cmd overlay will send inherited file descriptors to system_server.
# This module intentionally does not read/write statusbar resources.
run() {
    label="$1"
    shift
    "$@" </dev/null >/dev/null 2>&1
    rc=$?
    echo "$label=$rc"
    return "$rc"
}

ensure() {
    label="$1" target="$2" name="$3" resource="$4" encoded="$5"
    run "${label}_FABRICATE" cmd overlay fabricate --target "$target" --name "$name" "$resource" 0x05 "$encoded"
    f_rc=$?
    # A nonzero fabricate result can mean overlay already exists; enable is decisive.
    if ! run "${label}_ENABLE" cmd overlay enable --user 0 "com.android.shell:$name"; then
        echo "${label}_FAILED fabricate_rc=$f_rc"
        return 1
    fi
    return 0
}

ensure HEIGHT android s108compact_height android:dimen/navigation_bar_height 0x2401 || exit 11
ensure FRAME android s108compact_frame android:dimen/navigation_bar_frame_height 0x2401 || exit 12
ensure WIDTH com.android.systemui s108compact_keys com.android.systemui:dimen/navigation_key_width 0x3C01 || exit 13
echo 'NAVBAR_V10_APPLY_COMMANDS_OK'
exit 0
