# Android 13 crDroid UI sizing: manual fixes and persistent Magisk modules

Test device: S108, Android 13, 480×480 display, density override 198dpi.

## Status bar clock and right-side indicators

Tested resource values:
- `com.android.systemui:dimen/status_bar_padding_start` = **28dp** (encoded `0x1C01`)
- `com.android.systemui:dimen/status_bar_padding_end` = **16dp** (encoded `0x1001`)

Run the [manual apply script](../scripts/S108-Apply-StatusBar.sh) in a **root shell** or RTOSify root terminal. It fabricates/reenables numeric overlays under the `com.android.shell` namespace and refreshes SystemUI. The obsolete right 64dp overlay must remain disabled.

**Boot persistence verified on the tested watch:** the separate `s108_statusbar_insets` Magisk module restored the expected 28dp/16dp insets after a reboot. It can require multiple startup attempts and may briefly show 8dp/8dp before the overlay becomes active. Its startup service was **not modified** by the navbar fix.

## Compact three-button navbar

Original three-button (`navigation_mode=0`) values: bar height 48dp, frame height 48dp, key width 80dp. The tested compact version is:
- `android:dimen/navigation_bar_height` = **36dp** (`0x2401`)
- `android:dimen/navigation_bar_frame_height` = **36dp** (`0x2401`)
- `com.android.systemui:dimen/navigation_key_width` = **60dp** (`0x3C01`)

Run the [manual apply script](../scripts/S108-Apply-CompactNavbar.sh) in a root shell. The user verified it visually and stated its smaller footprint moved the buttons sufficiently left. **Do not add a left-alignment overlay**: the user considers the compact layout complete without changing alignment.

**Navbar persistence verified October 29, 2026:** the v10 Magisk module service restored 36dp/36dp/60dp after one normal reboot and retained those dimensions in two consecutive checks. The actual fix was redirecting the **individual Binder-facing `cmd overlay` processes** to `/dev/null`; increasing startup delay alone failed. The working module waits for `sys.boot_completed`, pauses 20 seconds and retries up to five times. See [reboot-verified guide, logs, source and rollback](ANDROID13-NAVBAR-PERSISTENCE.md). The preexisting older `s108_navbar_compact` module is disabled, not deleted.

## Failed experiments (do not repeat)

- **v7/v9 deferred boot scripts:** despite working manual overlays, commands running under the Magisk boot service returned Binder `Failed transaction (2147483646)`. Extending the delay to 45 seconds and attempting `su -c` within the service did not resolve it; v10 redirected the `cmd overlay` subprocess descriptors to `/dev/null`.
- **`su 0`** hung on this specific Magisk version, while `su -c` worked. Run Magisk root scripts as `adb shell su -c /path/to/script.sh`. 

- `cmd overlay fabricate` with string resource `config_navBarLayout` returned `For input string: ...`. This invocation only accepted encoded numeric payloads.
- `settings put secure sysui_nav_bar` either had no effect or caused navbar buttons to vanish temporarily. The setting was restored to `null`.
- Do **not** install the experimental left-alignment ZIP as a working fix.

## Restore or troubleshoot

Use `cmd overlay lookup --user 0` for each resource; verify numeric changes before restarting SystemUI. Disable only the `com.android.shell` overlay IDs created by the corresponding script, then refresh SystemUI. To recover navigation, the tested hardware mapper provides Left→Back and Right-double→Home.

These scripts affect **SystemUI presentation only**; they must not modify the LTE bootstrap, Google packages, or CPU/thermal tuning.
