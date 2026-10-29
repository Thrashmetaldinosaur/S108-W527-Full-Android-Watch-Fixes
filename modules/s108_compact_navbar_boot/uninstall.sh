#!/system/bin/sh
# Remove only this navbar fix's fabricated overlays. Never touch status-bar overlays.
cmd overlay disable --user 0 com.android.shell:s108compact_height >/dev/null 2>&1 || :
cmd overlay disable --user 0 com.android.shell:s108compact_frame >/dev/null 2>&1 || :
cmd overlay disable --user 0 com.android.shell:s108compact_keys >/dev/null 2>&1 || :
