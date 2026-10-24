# Android 13 crDroid UI sizing: confirmed manual fixes

Test device: S108, Android 13, 480×480 display, density override 198dpi.

## Status bar clock and right-side indicators

Tested resource values:
- `com.android.systemui:dimen/status_bar_padding_start` = **28dp** (encoded `0x1C01`)
- `com.android.systemui:dimen/status_bar_padding_end` = **16dp** (encoded `0x1001`)

Run the [manual apply script](../scripts/S108-Apply-StatusBar.sh) in a **root shell** or RTOSify root terminal. It fabricates/reenables numeric overlays under the `com.android.shell` namespace and refreshes SystemUI. The obsolete right 64dp overlay must remain disabled.

**Persistence is not yet independently established**: The Magisk startup mechanism experienced early-boot Binder transaction errors and the user observed the status-bar positioning eventually return, rather than reliably appear immediately at reboot. Do not describe a boot-time service as fixed unless tested after restarting.

## Compact three-button navbar

Original three-button (`navigation_mode=0`) values: bar height 48dp, frame height 48dp, key width 80dp. The tested compact version is:
- `android:dimen/navigation_bar_height` = **36dp** (`0x2401`)
- `android:dimen/navigation_bar_frame_height` = **36dp** (`0x2401`)
- `com.android.systemui:dimen/navigation_key_width` = **60dp** (`0x3C01`)

Run the [manual apply script](../scripts/S108-Apply-CompactNavbar.sh) in a root shell. The user verified it visually and stated its smaller footprint moved the buttons sufficiently left. **Do not add a left-alignment overlay**: the user considers the compact layout complete without changing alignment.

**Navbar persistence remains outstanding.** A 4-second post-boot service attempt was too early on this device. A separate deferred boot service (45 s plus retries) was proposed but not yet validated across reboot.

## Failed experiments (do not repeat)

- `cmd overlay fabricate` with string resource `config_navBarLayout` returned `For input string: ...`. This invocation only accepted encoded numeric payloads.
- `settings put secure sysui_nav_bar` either had no effect or caused navbar buttons to vanish temporarily. The setting was restored to `null`.
- Do **not** install the experimental left-alignment ZIP as a working fix.

## Restore or troubleshoot

Use `cmd overlay lookup --user 0` for each resource; verify numeric changes before restarting SystemUI. Disable only the `com.android.shell` overlay IDs created by the corresponding script, then refresh SystemUI. To recover navigation, the tested hardware mapper provides Left→Back and Right-double→Home.

These scripts affect **SystemUI presentation only**; they must not modify the LTE bootstrap, Google packages, or CPU/thermal tuning.
