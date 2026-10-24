#!/system/bin/sh
MODDIR=${0%/*}
touch "$MODDIR/disable"
/system/bin/sh "$MODDIR/stop.sh"
