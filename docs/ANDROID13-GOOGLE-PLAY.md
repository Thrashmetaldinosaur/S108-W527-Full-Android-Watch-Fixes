# Android 13 LiteGapps Play Services recovery (device-tested)

A crDroid Android 13 S108 with LiteGapps arm64 A13 v4.9 encountered Google Play Services crashes. Its `com.google.android.gms` package was initially supplied by a Magisk mount at `/system/product/priv-app/GmsCore/GmsCore.apk`; some Google process mount namespaces could not resolve that path.

**Successful repair on this watch:** Install the *same, already installed* LiteGapps GmsCore APK as an updated system app from a real `/data` path (rather than relying on a Magisk-only APK path in every process namespace). The watch preserved its SYSTEM/UPDATED_SYSTEM_APP/PRIVILEGED/PRODUCT flags after the update.

With root from an authorized ADB shell, first check actual source location. On the tested watch:

```sh
cp /data/adb/modules/litegapps/system/product/priv-app/GmsCore/GmsCore.apk /data/local/tmp/S108-GmsCore.apk
chmod 0644 /data/local/tmp/S108-GmsCore.apk
pm install -r /data/local/tmp/S108-GmsCore.apk
pm path com.google.android.gms
```

Verify `pm path` now points to `/data/app/.../base.apk` and confirm Play Services package privileges. Verify the file hash before and after copying; don't install an APK of a different version/signing key.

If Play Store says **“You're offline”** despite working Wi-Fi, inspect `settings get global restricted_networking_mode`. On this watch it was `1` and the tested fix was:

```sh
settings put global restricted_networking_mode 0
cmd netpolicy get restricted-mode
```

After adding a second Google account, a Play Store black screen resolved using `pm clear com.android.vending`. **Warning:** This resets local Play Store app data and settings; it does not require clearing Google account or GSF data. User retained both Google accounts.

This fix was tested on one device; backup modules/data before modifying system apps. Never publish actual Google account IDs, GSF IDs, tokens, or user-specific APKs.
