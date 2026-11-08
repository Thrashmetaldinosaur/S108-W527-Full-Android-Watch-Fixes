#!/system/bin/sh
[ "$ARCH" = arm64 ] || abort 'Requires an arm64 Retroid Pocket Nova.'
ui_print '- Installing Nova-only vendor/product 2022:3002 controller key layout'
ui_print '- Physical M1(306)->BUTTON_L2, M2(309)->BUTTON_R2'
ui_print '- Trigger axes will be injected by a root boot service into original controller'
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/bin/nova_m1m2_native_v3" 0 0 0755
set_perm "$MODPATH/system/usr/keylayout/Vendor_2022_Product_3002.kl" 0 0 0644
ui_print '- Stock partitions untouched; reboot to activate; Magisk can disable module.'
